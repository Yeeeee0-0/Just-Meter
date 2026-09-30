import AppKit
import SwiftUI

final class PluginHosting:NSHostingView<MeterRoot> {
    let meterModel:MeterModel
    init(engine:JMHandle) {meterModel=MeterModel(engine:engine,plugin:true);super.init(rootView:MeterRoot(model:meterModel));frame=NSRect(x:0,y:0,width:1000,height:760)}
    @MainActor required init(rootView:MeterRoot){fatalError("Use init(engine:)")}
    @MainActor required dynamic init?(coder:NSCoder){fatalError("Not supported")}
}
@_cdecl("jm_create_editor")
public func createEditor(_ engine:UnsafeMutableRawPointer)->UnsafeMutableRawPointer {
    Unmanaged.passRetained(PluginHosting(engine:engine)).toOpaque()
}
@_cdecl("jm_destroy_editor")
public func destroyEditor(_ editor:UnsafeMutableRawPointer) {let view=Unmanaged<PluginHosting>.fromOpaque(editor).takeRetainedValue();view.removeFromSuperview()}
@_cdecl("jm_attach_editor")
public func attachEditor(_ editor:UnsafeMutableRawPointer,_ parent:UnsafeMutableRawPointer) {let view=Unmanaged<PluginHosting>.fromOpaque(editor).takeUnretainedValue();let host=Unmanaged<NSView>.fromOpaque(parent).takeUnretainedValue();host.addSubview(view)}
@_cdecl("jm_resize_editor")
public func resizeEditor(_ editor:UnsafeMutableRawPointer,_ width:Int32,_ height:Int32) {Unmanaged<PluginHosting>.fromOpaque(editor).takeUnretainedValue().setFrameSize(NSSize(width:Int(width),height:Int(height)))}
