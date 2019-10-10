//
//  SRTSession.swift
//  VideoCast
//
//  Created by Tomohiro Matsuzawa on 2018/03/06.
//  Copyright © 2018年 CyberAgent, Inc. All rights reserved.
//

import Foundation

public typealias SRTSessionParameters = MetaData<(
    chunk: Int32,
    loglevel: SRTLogLevel,
    logfa: SRTLogFAs,
    logfile: String,
    internal_log: Bool,
    autoreconnect: Bool,
    reconnectPeriod: TimeInterval,
    quiet: Bool
    )>

public enum SRTClientState: Int {
    case none = 0
    case connecting
    case connected
    case error
    case notConnected
    case reconnecting
}

public typealias SRTSessionStateCallback = (_ session: SRTSession, _ state: SRTClientState) -> Void

open class SRTSession: IOutputSession {
    private let kPollDelay: TimeInterval = 0.1    // seconds - represents the time between polling

    private let uri: String

    private let callback: SRTSessionStateCallback

    private var loglevel: SRTLogLevel = .err
    private var logfa: SRTLogFAs = .general
    private var logfile: String = ""
    private var internal_log: Bool = false
    private var autoreconnect: Bool = true
    private var reconnectPeriod: TimeInterval = .init(5)
    private var quiet: Bool = false

    private var reconnecting: Bool = false

    private let jobQueue: JobQueue = .init("srt")

    private var state: SRTClientState = .none

    private var tar: SrtTarget?

    private var sendBuf: [Buffer] = .init()

    private var wroteBytes: Int = 0
    private var lostBytes: Int = 0
    private var lastReportedtLostBytes: Int = 0
    private var writeErrorLogTimer: Date = .init()

    private var thread: Thread?
    private let cond: NSCondition = .init()
    private var started: Bool = false
    private var ending: Atomic<Bool> = .init(false)

    private let statsManager: SrtStatsManager = .init()

    public init(uri: String, callback: @escaping SRTSessionStateCallback) {
        self.uri = uri
        self.callback = callback
        srt_startup()
    }

    deinit {
        Logger.debug("SRTSession:deinit")
        srt_cleanup()
    }

    open func setSessionParameters(_ parameters: IMetaData) {
        guard let params = parameters as? SRTSessionParameters, let data = params.data else {
            Logger.debug("unexpected return")
            return
        }
        SrtConf.transmit_chunk_size = data.chunk
        loglevel = data.loglevel
        logfa = data.logfa
        logfile = data.logfile
        internal_log = data.internal_log
        autoreconnect = data.autoreconnect
        reconnectPeriod = data.reconnectPeriod
        quiet = data.quiet

        start()
    }

    open func start() {
        if !started {
            started = true
            thread = Thread(target: self, selector: #selector(transmitThread), object: nil)
            thread?.start()
        }
    }

    open func stop(_ callback: @escaping StopSessionCallback) {
        statsManager.stop()
        statsManager.removeThroughputCallback()
        ending.value = true
        cond.broadcast()
        if started {
            thread?.cancel()
            started = false
        }

        callback()
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    open func pushBuffer(_ data: UnsafeRawPointer, size: Int, metadata: IMetaData) {
        guard !ending.value else { return }
        assert (size % 188 == 0)

        var len = size
        var offset = 0

        if size == 0 {
            return
        }
        while len > 0 {
            let buf: Buffer
            if let last = sendBuf.last, last.buffer.count < SrtConf.transmit_chunk_size {
                buf = last
            } else {
                buf = Buffer()
                sendBuf.append(buf)
            }
            let copyLen = min(Int(SrtConf.transmit_chunk_size) - buf.buffer.count, size)
            buf.buffer.append(data.assumingMemoryBound(to: UInt8.self) + offset,
                               count: copyLen)
            len -= copyLen
            offset += copyLen
        }

        // SRT bandwidth estimation requires that most packets are sent bursty
        // https://github.com/Haivision/srt/blob/v1.3.1/srtcore/window.cpp#L201-L222
        if sendBuf.count >= 10 {
            while !sendBuf.isEmpty {
                guard let buf = sendBuf.first, buf.buffer.count >= SrtConf.transmit_chunk_size else { break }
                assert(buf.buffer.count == SrtConf.transmit_chunk_size)
                sendBuf.remove(at: 0)

                // make the lamdba capture the data
                jobQueue.enqueue {
                    if !self.ending.value {
                        do {
                            guard let tar = self.tar else { return }

                            try buf.buffer.withUnsafeBytes {
                                guard let data = $0.baseAddress?.assumingMemoryBound(to: Int8.self) else {
                                    Logger.error("unaligned pointer \($0)")
                                    return
                                }
                                let size = buf.buffer.count
                                if !tar.isOpen {
                                    self.lostBytes += size
                                } else if try !tar.write(data, size: size) {
                                    self.lostBytes += size
                                } else {
                                    self.wroteBytes += size
                                }
                            }

                            if !self.quiet && (self.lastReportedtLostBytes != self.lostBytes) {
                                let now: Date = .init()
                                if now.timeIntervalSince(self.writeErrorLogTimer) >= 5 {
                                    Logger.debug("\(self.lostBytes) bytes lost, \(self.wroteBytes) bytes sent")
                                    self.writeErrorLogTimer = now
                                    self.lastReportedtLostBytes = self.lostBytes
                                }
                            }
                        } catch {
                            Logger.error("ERROR: \(error)")
                        }
                    }
                }
            }
        }
    }

    open func setBandwidthCallback(_ callback: @escaping BandwidthCallback) {
        statsManager.setThroughputCallback(callback)
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    @objc private func transmitThread() {
        loglevel.setLogLevel()
        logfa.setLogFA()

        Thread.current.name = "jp.co.cyberagent.VideoCast.srt.transmission"

        if internal_log {
            var NAME = "SRTLIB".cString(using: String.Encoding.utf8)!
            srt_setlogflags( 0
                | SRT_LOGF_DISABLE_TIME
                | SRT_LOGF_DISABLE_SEVERITY
                | SRT_LOGF_DISABLE_THREADNAME
                | SRT_LOGF_DISABLE_EOL
            )
            srt_setloghandler(&NAME, { (_, level, file, line, area, message) in
                let file: String = .init(cString: file!)
                let area: String = .init(cString: area!)
                let message: String = .init(cString: message!)

                Logger.debug("[\(file):\(line)(\(area)]{\(level)} \(message)")
            })
        } else if !logfile.isEmpty {
            _ = logfile.withCString { udtSetLogStream($0) }
        }

        if !quiet {
            Logger.debug("Media path: \(uri)")
        }

        var tarConnected: Bool = false
        var firstConnection: Bool = true

        let pollid: Int32 = srt_epoll_create()
        guard pollid >= 0 else {
            Logger.error("Can't initialize epoll")
            setClientState(.error)
            return
        }

        do {
            // Now loop until broken
            while !ending.value {
                cond.lock()
                defer {
                    cond.unlock()
                }

                if !ending.value {
                    if reconnecting {
                        cond.wait(until: Date.init(timeIntervalSinceNow: reconnectPeriod))
                        reconnecting = false
                    } else {
                        cond.wait(until: Date.init(timeIntervalSinceNow: kPollDelay))
                    }
                }
                guard !ending.value else {
                    if let tar = tar {
                        tar.close()
                    }
                    break
                }

                if tar == nil {
                    tar = try SrtTarget.create(uri, pollid: pollid)
                    guard tar != nil else {
                        Logger.error("Unsupported target type")
                        setClientState(.error)
                        return
                    }

                    wroteBytes = 0
                    lostBytes = 0
                    lastReportedtLostBytes = 0

                    setClientState(.connecting)
                }

                var srtrfdslen: Int32 = 1
                var srtrfds: [SRTSOCKET] = .init(repeating: SRT_INVALID_SOCK, count: 1)
                var srtwfdslen: Int32 = 1
                var srtwfds: [SRTSOCKET] = .init(repeating: SRT_INVALID_SOCK, count: 1)
                if srt_epoll_wait(pollid,
                                  &srtrfds, &srtrfdslen, &srtwfds, &srtwfdslen,
                                  0,
                                  nil, nil, nil, nil) >= 0 {
                    /*if false
                     {
                     Logger.debug("Event: srtrfdslen \(srtrfdslen) sysrfdslen \(sysrfdslen)")
                     }*/

                    var doabort: Bool = false
                    if srtrfdslen > 0 || srtwfdslen > 0 {
                        let s = srtrfdslen > 0 ? srtrfds[0] : srtwfds[0]
                        guard let t = tar, t.getSRTSocket() == s else {
                            Logger.error("Unexpected socket poll: \(s)")
                            doabort = true
                            setClientState(.error)
                            break
                        }

                        let dirstring = "target"

                        let status = srt_getsockstate(s)
                        if false && status != SRTS_CONNECTED {
                            Logger.debug("\(dirstring) status \(status)")
                        }
                        switch status {
                        case SRTS_LISTENING:
                            if false && !quiet {
                                Logger.debug("New SRT client connection")
                            }

                            guard let tar = tar else {
                                Logger.error("SRT client hasn't been created")
                                break
                            }

                            let res = try tar.acceptNewClient()
                            if !res {
                                Logger.error("Failed to accept SRT connection")
                                doabort = true
                                setClientState(.error)
                                break
                            }

                            srt_epoll_remove_usock(pollid, s)

                            let ns = tar.getSRTSocket()
                            var events: Int32 = Int32(SRT_EPOLL_IN.rawValue | SRT_EPOLL_ERR.rawValue)
                            if srt_epoll_add_usock(pollid, ns, &events) != 0 {
                                Logger.error("Failed to add SRT client to poll, \(ns)")
                                doabort = true
                                setClientState(.error)
                            } else {
                                if !quiet {
                                    Logger.debug("Accepted SRT \(dirstring) connection")
                                }
                                tarConnected = true
                                setClientState(.connected)
                                firstConnection = false
                            }
                        case SRTS_BROKEN, SRTS_NONEXIST, SRTS_CLOSED:
                            if tarConnected {
                                if !quiet {
                                    Logger.debug("SRT target disconnected")
                                }
                                tarConnected = false
                            }

                            if firstConnection || ending.value || !autoreconnect {
                                setClientState(.notConnected)
                                doabort = true
                            } else {
                                // force re-connection
                                srt_epoll_remove_usock(pollid, s)
                                statsManager.stop()
                                setClientState(.reconnecting)
                                reconnecting = true
                                tar = nil
                            }
                        case SRTS_CONNECTED:
                            if !tarConnected {
                                if !quiet {
                                    Logger.debug("SRT target connected")
                                }
                                tarConnected = true
                                firstConnection = false
                                setClientState(.connected)
                                if let tar = tar {
                                    statsManager.start(tar.sock)
                                }
                            }

                        default:
                            // No-Op
                            break
                        }
                    }

                    if doabort {
                        break
                    }
                } else {
                    let str = String(cString: udtGetLastError().message)
                    Logger.debug(str)
                }
            }
        } catch {
            Logger.error("ERROR: \(error)")
            setClientState(.error)
        }
    }

    private func setClientState(_ state: SRTClientState) {
        self.state = state
        callback(self, state)
    }

}
