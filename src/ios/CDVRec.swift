import AVFoundation
import Foundation
import Accelerate



@objc(CDVRec) class CDVRec : CDVPlugin, AVAudioPlayerDelegate {
    var engine:AVAudioEngine? = nil;
    var RECORDING_DIR:String?
    var isRecording:Bool = false
    var pushBufferCallBackId:String?
    var audioSettings:[String:Any]?
    var bufferSize = 4096
    // Audio の型定義
    struct Audio: Codable {
        var name: String
        var duration:String
        var path:String
    }
    
    // 録音終了後の音源
    struct RecordedAudio: Codable {
        var audios: [Audio]
        var full_audio: Audio
        var folder_id: String
    }
    
    /* folder structure
     
     // divided file
     Documents/recording/1560480886/divided/hogehoge.m4a
     Documents/recording/1560480886/divided/fugafuga.m4a
     Documents/recording/1560480886/divided/foofoo.m4a
     
     // joined file
     Documents/recording/1560480886/joined/joined_audio0.m4a
     Documents/recording/1560480886/joined/joined_audio1.m4a
     Documents/recording/1560480886/joined/joined_audio2.m4a
     
    */

    var folder_id: String = "default_id"
    var audio_index: Int32 = 0
    var audio_urls: [String]?
    var folder_path: String?
    var currentAudioName: String? // 現在録音中のファイル
    var currentAudios: [Audio]?// 現在録音中のファイルを順番を保証して配置
    var currentJoinedAudioName:String? // 連結済みファイルの最新のものの名前
    var queue: [Audio]?
    
    override func pluginInitialize() {
        print("[cordova plugin REC. intializing]")
        self.engine = AVAudioEngine()
        RECORDING_DIR = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! + "/recording"
        currentAudios = []
        queue = []
        bufferSize = 4096;
        audioSettings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRatePerChannelKey: 16,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
    }
    
    @objc func initSettings(_ command: CDVInvokedUrlCommand) {
        let args = command.arguments
        let settings = args![0] as! [String: Any];

        for (key, value) in settings as! [String:Any] {
            self.audioSettings![key] = value
        }
        
        
        // cordova result
        let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: true)
        self.commandDelegate.send(result, callbackId:command.callbackId)
    }
    
    // start recording
    @objc func start(_ command: CDVInvokedUrlCommand) {
        
        // 既にスタートしてたら エラーを返す
        if (isRecording) {
            let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs:"already starting")
            self.commandDelegate.send(result, callbackId:command.callbackId)
            return
        }
        
        // リセットをかける
        audio_index = 0
        currentAudios = []
        queue = []
        
        let path = self.getNewFolderPath()
        
        startRecord(path: path)
        
        isRecording = true
        
        // 問題なければ result
        let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: true)
        self.commandDelegate.send(result, callbackId:command.callbackId)
    }
    
    // stop recording
    @objc func stop(_ command: CDVInvokedUrlCommand) {
        
        // 既にスタートしていなかったらエラーを返す
        if (!isRecording) {
            let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs:"not starting")
            self.commandDelegate.send(result, callbackId:command.callbackId)
            return
        }
        
        // pause するだけ
        pauseRecord()
        isRecording = false
        
        
        let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: true)
        self.commandDelegate.send(result, callbackId:command.callbackId)
    }
    
    
    // pause recording
    @objc func pause(_ command: CDVInvokedUrlCommand) {
        
        // スタートしていなかったら エラーを返す
        if (!isRecording) {
            let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs:"not starting")
            self.commandDelegate.send(result, callbackId:command.callbackId)
            return
        }
        
        // レコーディング中断
        pauseRecord()
        isRecording = false
    
        // cordova result
        let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: true)
        self.commandDelegate.send(result, callbackId:command.callbackId)
    }
    
    // resume recording
    @objc func resume(_ command: CDVInvokedUrlCommand) {
        
        // 既にスタートしてたら エラーを返す
        if (isRecording) {
            let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs:"already starting")
            self.commandDelegate.send(result, callbackId:command.callbackId)
            return
        }
        
        let path = self.getCurrentFolderPath()
        self.startRecord(path: path)
        isRecording = true
        
        let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs:"pause success")
        self.commandDelegate.send(result, callbackId:command.callbackId)
    }
    
    // 音声ファイルをエクスポートする
    @objc func export(_ command: CDVInvokedUrlCommand) {
        // 現在の音声ファイルをつなげる
        let join_audio = self.joinRecord()!
        
        // 送るオーディオファイルの作成
        let record_audio = RecordedAudio(audios: currentAudios!, full_audio: join_audio, folder_id: folder_id)
        
        // JSON データの形成
        let encoder = JSONEncoder()
        let data = try! encoder.encode(record_audio)
        
        // Dictionary 型にキャスト
        let sendMessage = try! JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
        
        let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: sendMessage)
        self.commandDelegate.send(result, callbackId: command.callbackId)
    }
    
    // 音声バッファを送る
    @objc func onPushBuffer (_ command: CDVInvokedUrlCommand) {
        pushBufferCallBackId = command.callbackId;
    }
    
    @objc func getRecordingFolders(_ command: CDVInvokedUrlCommand) {
        do {
            let fileNames = try FileManager.default.contentsOfDirectory(atPath: RECORDING_DIR!)
            let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs:fileNames)
            self.commandDelegate.send(result, callbackId:command.callbackId)
        }
        catch let err {
            let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs:"can't get index: \(err)")
            self.commandDelegate.send(result, callbackId:command.callbackId)
        }
        
    }
    
    @objc func removeFolder(_ command: CDVInvokedUrlCommand) {
        let folder_id:String = command.argument(at: 0, withDefault: String.self) as! String
        removeFolder(id: folder_id)
        let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs:"removed!")
        self.commandDelegate.send(result, callbackId:command.callbackId)
    }
    
    @objc func removeCurrentFolder(_ command: CDVInvokedUrlCommand) {
        if (folder_id != nil) {
            removeFolder(id: folder_id)
            let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs:"removed!")
            self.commandDelegate.send(result, callbackId:command.callbackId)
        }
        else {
            let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs:"can't remove")
            self.commandDelegate.send(result, callbackId:command.callbackId)
        }
    }
    
    @objc func setFolder(_ command: CDVInvokedUrlCommand) {
        self.folder_id = command.argument(at: 0, withDefault: String.self) as! String
        let d = try! FileManager.default.contentsOfDirectory(atPath: (RECORDING_DIR! + "/\(folder_id)/divided/"))
        self.audio_index = Int32(d.count - 1)
        let j = try! FileManager.default.contentsOfDirectory(atPath: (RECORDING_DIR! + "/\(folder_id)/joined/"))
        let audio_path = URL(fileURLWithPath: (RECORDING_DIR! + "/\(folder_id)/joined/\(j.first!)"))
        
        let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: audio_path.absoluteString)
        self.commandDelegate.send(result, callbackId:command.callbackId)
    }
    // 波形を取得する
    @objc func getWaveForm(_ command: CDVInvokedUrlCommand) {
        let joined_audio_path = getCurrentJoinedAudioURL()
        let audioFile = try! AVAudioFile(forReading: joined_audio_path)
        let nframe = Int(audioFile.length)
        let PCMBuffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: AVAudioFrameCount(nframe))!
        try! audioFile.read(into: PCMBuffer)
        let bufferData = Data(buffer: UnsafeMutableBufferPointer<Float>(start:PCMBuffer.floatChannelData![0], count: nframe))
        let pcmBufferPath = URL(fileURLWithPath: RECORDING_DIR! + "/\(folder_id)/temppcmbuffer")
        try! bufferData.write(to: pcmBufferPath)
        let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: pcmBufferPath.absoluteString)
        self.commandDelegate.send(result, callbackId: command.callbackId)
    }
    
    private func removeFolder(id:String) {
        let folder_url = URL(fileURLWithPath: RECORDING_DIR! + "/\(id)")
        if FileManager.default.fileExists(atPath: folder_url.path) {
            try! FileManager.default.removeItem(atPath: folder_url.path)
        }
    }
    
    // start private func
    private func startRecord(path: URL) {
        do {
            // audio setting
            let audioSettings = self.audioSettings!
            
            // audio file name
            let timestamp = String(Int(NSDate().timeIntervalSince1970));
            let id = generateId(length: 16)
            currentAudioName = "\(id)_\(timestamp)";
            
            // フォルダがなかったらフォルダ生成
            let folder_path = URL(string: path.absoluteString + "/queue")!;
            if (!FileManager.default.fileExists(atPath: folder_path.absoluteString)) {
                try FileManager.default.createDirectory(at: URL(fileURLWithPath: folder_path.path), withIntermediateDirectories: true)
            }
            
            // base data
            let filePath = folder_path.appendingPathComponent("\(currentAudioName!).m4a")
            
            // audio file
            let audioFile = try! AVAudioFile(forWriting: filePath, settings: audioSettings)
            
            
            // write buffer
            let inputNode = self.engine?.inputNode
            inputNode!.installTap(onBus: 0, bufferSize: UInt32(self.bufferSize), format: nil) { (buffer:AVAudioPCMBuffer, when:AVAudioTime) in
                do {
                    // call back が登録されていたら
                    if ((self.pushBufferCallBackId) != nil) {
                        let b = Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count:Int(buffer.frameLength)))
                        let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: b)
                        result?.keepCallback = true
                        self.commandDelegate.send(result, callbackId: self.pushBufferCallBackId)
                    }
                    
                    try audioFile.write(from: buffer)
                }
                catch let err {
                    print("[cdv plugin REC: error]", err)
                }
            }

            // engine start
            do {
                try self.engine?.start()
                audio_index += 1 // increment index

                
            }
            catch let error {
                print("[cdv plugin REC] engin start error", error)
            }
            

        }
            
        catch let error {
            print("[cdv plugin REC] Audio file error", error)
        }
    }
    
    // 音声をとめる
    private func pauseRecord() -> Bool {
        
        // stop engine
        self.engine?.stop();
        self.engine?.inputNode.removeTap(onBus: 0)
        
        // 現在録音したデータを queue に追加する
        let folder_path = getCurrentFolderPath().absoluteString
        let fullAudioPath = folder_path + "queue/\(currentAudioName!).m4a"
        let asset = AVURLAsset(url: URL(string: fullAudioPath)!)
        let data = Audio(name: currentAudioName!, duration: String(asset.duration.value), path: fullAudioPath)
        queue!.append(data)
        
        // 追加が終わったら true
        return true;
    }
    
    
    private func joinRecord() -> Data {
        // 録音した全部のファイルをつなげる
        let join_audio = self.joinRecord()!
        
        let record_audio = RecordedAudio(audios: currentAudios!, full_audio: join_audio, folder_id: folder_id)
        
        // 返す JSON データの生成
        let encoder = JSONEncoder()
        let data = try! encoder.encode(record_audio)
        return data
    }
    
    private func getCurrentJoinedAudioURL() -> URL {
        return URL(fileURLWithPath: RECORDING_DIR! + "/\(folder_id)/joined/joined.m4a")
    }
    
    
    private func createNewFolder() -> String {
        // 新しい folder id を生成してそこに保存する (unixtime stamp)
        folder_id = String(Int(NSDate().timeIntervalSince1970))
        let path = RECORDING_DIR! + "/\(folder_id)"
        
        do {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        }
        catch {
            print("[cdv plugin rec: create folder error]")
        }
        
        return path
    }
    
    
    private func getNewFolderPath() -> URL {
        return URL(string: createNewFolder())!
    }
    
    private func getCurrentFolderPath() -> URL {
        let documentDir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        return URL(fileURLWithPath: "\(documentDir)/recording/\(folder_id)", isDirectory: true)
    }
    // random id の取得
    private func generateId(length: Int) -> String {
        let base = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        var randomString: String = ""
        
        for _ in 0..<length {
            let randomValue = arc4random_uniform(UInt32(base.characters.count))
            randomString += String(base[base.index(base.startIndex, offsetBy: Int(randomValue))])
        }
        return randomString
    }
    // folder 内のオーディオファイルを連結して返す
    private func joinRecord() -> Audio? {
        
        var nextStartTime = kCMTimeZero
        var result:Audio?
        let composition = AVMutableComposition()
        let track = composition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        let semaphore = DispatchSemaphore(value: 0)
        
        
        let joinedFilePath = URL(fileURLWithPath: RECORDING_DIR! + "/\(folder_id)/joined/joined.m4a", isDirectory: false)
        let isJoinedFile = FileManager.default.fileExists(atPath: joinedFilePath.path);
        var audio_files:[String] = [];
        
        var currentQueue = queue!;
        let audio_folder_path = RECORDING_DIR! + "/\(folder_id)/divided";
        
        if (isJoinedFile) {
            audio_files.append(joinedFilePath.absoluteString)
        }
        
        currentQueue    .forEach { (item:Audio) in
            audio_files.append(item.path)
        }
        
        for audio in audio_files {
            let fullPath = URL(string: audio)!
            if FileManager.default.fileExists(atPath:  fullPath.path) {
                let asset = AVURLAsset(url: fullPath)
                if let assetTrack = asset.tracks.first {
                    let timeRange = CMTimeRange(start: kCMTimeZero, duration: asset.duration)
                    do {
                        try track!.insertTimeRange(timeRange, of: assetTrack, at: nextStartTime)
                        nextStartTime = CMTimeAdd(nextStartTime, timeRange.duration)
                    } catch {
                        print("concatenateError : \(error)")
                    }
                }
            }
        }
        
        if let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) {
            let folderPath = URL(fileURLWithPath: RECORDING_DIR! + "/\(folder_id)/joined" , isDirectory: true)
            if !FileManager.default.fileExists(atPath: folderPath.path) {
               try! FileManager.default.createDirectory(atPath: folderPath.path, withIntermediateDirectories: false)
            }
            
            let tempPath = folderPath.absoluteString + "temp.m4a";
            var concatFileSaveURL = URL(string: tempPath)!
            
            exportSession.outputFileType = AVFileType.m4a
            exportSession.outputURL = concatFileSaveURL
            
            exportSession.exportAsynchronously(completionHandler: {
                switch exportSession.status {
                
                // ファイル連結成功時
                case .completed:
                    
                    let joined_folder = URL(string: folderPath.absoluteString + "joined.m4a")!
                    
                    // もとの joined.m4a を削除
                    if FileManager.default.fileExists(atPath: joined_folder.path) {
                        try! FileManager.default.removeItem( atPath: joined_folder.path )
                    }
                    
                    
                    // ファイル名変更 temp.m4a => joined.m4a
                    try! FileManager.default.moveItem(atPath: concatFileSaveURL.path, toPath: joined_folder.path)
                    
                    // Queue フォルダーに移動。移動後 queue -> divided フォルダーに移動
                    currentQueue = currentQueue.map { (item) in
                        let from = URL(string: item.path)!
                        let to = URL(fileURLWithPath: "\(audio_folder_path)/\(item.name).m4a")
                        
                        if !FileManager.default.fileExists(atPath: audio_folder_path) {
                            try! FileManager.default.createDirectory(atPath: audio_folder_path, withIntermediateDirectories: true)
                        }
                        
                        try! FileManager.default.moveItem(atPath: from.path, toPath: to.path)
                        return Audio(name: item.name, duration: item.duration, path: to.absoluteString)
                    }
                    
                    self.currentAudios?.append(contentsOf: currentQueue)
                    
                    self.queue = [] // Queue をリセット
                    
                    
                    let asset = AVURLAsset(url: joined_folder);
                    
                    result = Audio(name:"joined_audio", duration: String(asset.duration.value), path: joined_folder.absoluteString)
                    
                    semaphore.signal()
                case .failed, .cancelled:
                    print("[join error: failed or cancelled]", exportSession.error.debugDescription)
                    semaphore.signal()
                case .waiting:
                    print(exportSession.progress);
                default:
                    print("[join error: other error]", exportSession.error.debugDescription)
                    semaphore.signal()
                }
            })
        }
        
        semaphore.wait()
        return result
    }
    
}
