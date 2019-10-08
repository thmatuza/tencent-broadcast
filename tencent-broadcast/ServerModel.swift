//
//  ServerModel.swift
//  tencent-broadcast
//
//  Created by 松澤 友弘 on 2019/10/04.
//  Copyright © 2019 CyberAgent. All rights reserved.
//

import Foundation

@objc(Server)
class Server: NSObject, NSCoding {
    var desc: String
    var url: String
    var streamName: String

    init(desc: String, url: String, streamName: String) {
        self.desc = desc
        self.url = url
        self.streamName = streamName
    }

    required convenience init?(coder aDecoder: NSCoder) {
        guard let desc = aDecoder.decodeObject(forKey: "desc") as? String,
            let url = aDecoder.decodeObject(forKey: "url") as? String,
            let streamName = aDecoder.decodeObject(forKey: "streamName") as? String
            else { fatalError() }
        self.init(desc: desc, url: url, streamName: streamName)
    }

    func encode(with aCoder: NSCoder) {
        aCoder.encode(desc, forKey: "desc")
        aCoder.encode(url, forKey: "url")
        aCoder.encode(streamName, forKey: "streamName")
    }
}

class ServerModel {
    static let shared = ServerModel()

    private let userDefaults = UserDefaults()
    private let serversKey = "Server.Servers"
    private let selectedKey = "Server.Selected"

    private var _servers: [Server]
    private var _selected: Int

    var servers: [Server] {
        get {
            return _servers
        }
        set {
            _servers = newValue
            guard let encodedData =
                try? NSKeyedArchiver.archivedData(withRootObject: _servers, requiringSecureCoding: false) else {
                fatalError("Archive failed")
            }
            userDefaults.set(encodedData, forKey: serversKey)
            userDefaults.synchronize()
        }
    }

    var selected: Int {
        get {
            return _selected
        }
        set {
            _selected = newValue
            userDefaults.set(_selected, forKey: selectedKey)
            userDefaults.synchronize()
        }
    }

    var server: Server {
        return _servers[_selected]
    }

    private init() {
        if let decoded = userDefaults.object(forKey: serversKey) as? Data {
            do {
                _servers = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(decoded) as? [Server] ?? []
            } catch {
                _servers = []
            }
        } else {
            _servers = []
        }

        _selected = userDefaults.integer(forKey: selectedKey)
    }
}
