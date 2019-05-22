import AVFoundation

@objc(CDVRec) class CDVRec :CDVPlugin {
    
    var engine:AVAudioEngine? = nil;
    let TEMP_DIRECTORY = NSHomeDirectory() + "/tmp"
    let SUPPORT_DIRECTORY = NSHomeDirectory() + "/Library/Application Support"
    
    
    override func pluginInitialize() {
        print("hi! this is cordova plugin REC. intializing now ! ....")
        self.engine = AVAudioEngine();
    }
    // start recording
    @objc func start(_ command: CDVInvokedUrlCommand) {
        let callbackId = command.callbackId
        
        do {
            let documentDir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
            let filePath = URL(fileURLWithPath: documentDir + "/sample.caf")

            let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 1, interleaved: true)
            
            let audioFile = try AVAudioFile(forWriting: filePath, settings: format!.settings)
            
            let buffer:AVAudioPCMBuffer;
            
            let inputNode = self.engine?.inputNode
            inputNode!.installTap(onBus: 0, bufferSize: 4096, format: nil) { (buffer, when) in
                print("writing")
            }
            
            do {
                
                try self.engine?.start()
            }
            catch let error {
                print("[cdv plugin REC] engin start error", error)
            }
        }
        
        catch let error {
            print("[cdv plugin REC] Audio file error", error)
        }
        
        
        let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs:"start success")
        self.commandDelegate.send(result, callbackId:command.callbackId)
        
        
    }
    // stop recording
    @objc func stop(_ command: CDVInvokedUrlCommand) {
        self.engine?.stop();
        self.engine?.inputNode.removeTap(onBus: 0)
        
        
        let callbackId = command.callbackId
        let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs:"stop success")
        self.commandDelegate.send(result, callbackId:command.callbackId)
    }
    // pause recording
    @objc func pause(_ command: CDVInvokedUrlCommand) {
        let callbackId = command.callbackId
        let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs:"pause success")
        self.commandDelegate.send(result, callbackId:command.callbackId)
    }
    // resume recording
    @objc func resume(_ command: CDVInvokedUrlCommand) {
        let callbackId = command.callbackId
        let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs:"pause success")
        self.commandDelegate.send(result, callbackId:command.callbackId)
    }

}


// buffer を audio に
//class AudioBufferFormatHelper {
//    static func PCMFormat() -> AVAudioFormat? {
//        return AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 1, interleaved: false)
//    }
//    
//    static func AACFormat() -> AVAudioFormat? {
//
//        var outDesc = AudioStreamBasicDescription(
//            mSampleRate: 44100,
//            mFormatID: kAudioFormatMPEG4AAC,
//            mFormatFlags: 0,
//            mBytesPerPacket: 0,
//            mFramesPerPacket: 0,
//            mBytesPerFrame: 0,
//            mChannelsPerFrame: 1,
//            mBitsPerChannel: 0,
//            mReserved: 0)
//        let outFormat = AVAudioFormat(streamDescription: &outDesc)
//        return outFormat
//    }
//}
//
//
//class AudioBufferConverter {
//    static var lpcmToAACConverter: AVAudioConverter! = nil
//
//    // buffer to convertToAAC
//    static func convertToAAC(from buffer: AVAudioBuffer, error outError: NSErrorPointer) -> AVAudioCompressedBuffer? {
//
//        let outputFormat = AudioBufferFormatHelper.AACFormat()
//        let outBuffer = AVAudioCompressedBuffer(format: outputFormat!, packetCapacity: 8, maximumPacketSize: 768)
//
//        if lpcmToAACConverter == nil {
//            let inputFormat = buffer.format
//            lpcmToAACConverter = AVAudioConverter(from: inputFormat, to: outputFormat!)
//            lpcmToAACConverter.bitRate = 32000
//        }
//
//        self.convert(withConverter: lpcmToAACConverter, from: buffer, to: outBuffer, error: outError)
//        return outBuffer
//
//    }
//    static func convertToPCM() {
//        let outputFormat = AudioBufferFormatHelper.PCMFormat()
//        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat!, frameCapacity: 4410) else {
//            return nil
//        }
//
//        //init converter once
//        if aacToLPCMConverter == nil {
//            let inputFormat = buffer.format
//
//            aacToLPCMConverter = AVAudioConverter(from: inputFormat, to: outputFormat!)
//        }
//
//        self.convert(withConverter: aacToLPCMConverter, from: buffer, to: outBuffer, error: outError)
//
//        return outBuffer
//    }
//
//    static func convert(withConverter: AVAudioConverter, from sourceBuffer: AVAudioBuffer, to destinationBuffer: AVAudioBuffer, error outError: NSErrorPointer) {
//        var newBufferAvailable = true
//        let inputBlock : AVAudioConverterInputBlock = { inNumPackets, outStatus in
//            if newBufferAvailable {
//                outStatus.pointee = .haveData
//                newBufferAvailable = false
//                return sourceBuffer
//            }
//            else {
//                outStatus.pointee = .noDataNow
//                return nil
//            }
//
//        }
//
//        let status = withConverter.convert(to: destinationBuffer, error: outError, withInputFrom: inputBlock)
//        print("status: \(status.rawValue)")
//    }
//
//
//}


//class AudioService {
//    var buffer: UnsafeMutablePointer
//
//    var audioQueueObject: AudioQueueRef
//    // 再生/録音のパケット数
//    let numPacketsToRead: UInt32 = 1024
//    let numPacketsToWrite: UInt32 = 1024
//
//    // 再生/録音 の読み出し、書き出しの位置
//    var startingPacketCount: UInt32
//
//
//    var maxPacketCount: UInt32
//
//    let bytesPerPacket: UInt32 = 2
//    let seconds: UInt32 = 10
//
//    var audioFormat: AudioStreamBasicDescription {
//        return AudioStreamBasicDescription(
//            mSampleRate: 480000, mFormatID: <#T##AudioFormatID#>, mFormatFlags: <#T##AudioFormatFlags#>, mBytesPerPacket: <#T##UInt32#>, mFramesPerPacket: <#T##UInt32#>, mBytesPerFrame: <#T##UInt32#>, mChannelsPerFrame: <#T##UInt32#>, mBitsPerChannel: <#T##UInt32#>, mReserved: <#T##UInt32#>
//        )
//    }
//}
