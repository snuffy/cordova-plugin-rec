@objc(Rec) class Rec :CDVPlugin {
  override func pluginInitialize() {
    print("hi! this is cordova plugin REC. intializing now ! ....")
  }
  // start recording
  @objc func start(_ command: CDVInvokedUrlCommand) {
    let callbackId = command.callbackId
    let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs:"start success")
    self.commandDelegate.send(result, callbackId:command.callbackId)
  }
  // stop recording
  @objc func stop(_ command: CDVInvokedUrlCommand) {
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
  @objc func pause(_ command: CDVInvokedUrlCommand) {
    let callbackId = command.callbackId
    let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs:"pause success")
    self.commandDelegate.send(result, callbackId:command.callbackId)
  }
}