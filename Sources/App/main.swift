import AppKit
import SwiftUI

final class AppDelegate:NSObject,NSApplicationDelegate,NSWindowDelegate {
    var window:NSWindow!
    var model:MeterModel!
    func applicationDidFinishLaunching(_ notification:Notification) {
        model=MeterModel()
        let rect=NSRect(x:0,y:0,width:1000,height:780)
        window=NSWindow(contentRect:rect,styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
        window.title="Just Meter";window.titlebarAppearsTransparent=false;window.backgroundColor = .windowBackgroundColor;window.isOpaque=false;window.minSize=NSSize(width:780,height:660);window.delegate=self
        window.contentView=NSHostingView(rootView:MeterRoot(model:model));window.center();window.setFrameAutosaveName("JustMeter.main");model.window=window;model.persist()
        model.languageDidChange = { [weak self] in self?.configureMenus() }
        configureMenus()
        NSApp.setActivationPolicy(.regular);window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)
        if let i=CommandLine.arguments.firstIndex(of:"--analyze"),CommandLine.arguments.count>i+1 {model.audio?.analyze(URL(fileURLWithPath:CommandLine.arguments[i+1]))}
    }
    func configureMenus() {
        let menu=NSMenu();let appMenuItem=NSMenuItem();menu.addItem(appMenuItem);let appMenu=NSMenu();appMenuItem.submenu=appMenu
        appMenu.addItem(withTitle:model.text("关于 Just Meter"),action:#selector(about),keyEquivalent:"")
        appMenu.addItem(withTitle:model.text("设置…"),action:#selector(settings),keyEquivalent:",")
        appMenu.addItem(.separator());appMenu.addItem(withTitle:model.text("隐藏 Just Meter"),action:#selector(NSApplication.hide(_:)),keyEquivalent:"h")
        appMenu.addItem(withTitle:model.text("退出 Just Meter"),action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q")
        let fileItem=NSMenuItem();menu.addItem(fileItem);let file=NSMenu(title:model.text("文件"));fileItem.submenu=file
        file.addItem(withTitle:model.text("分析音频文件…"),action:#selector(openFile),keyEquivalent:"o");file.addItem(withTitle:model.text("导出 CSV…"),action:#selector(export),keyEquivalent:"e")
        let editItem=NSMenuItem();menu.addItem(editItem);let edit=NSMenu(title:model.text("编辑"));editItem.submenu=edit
        edit.addItem(withTitle:model.text("撤销"),action:Selector(("undo:")),keyEquivalent:"z");edit.addItem(withTitle:model.text("剪切"),action:#selector(NSText.cut(_:)),keyEquivalent:"x");edit.addItem(withTitle:model.text("复制"),action:#selector(NSText.copy(_:)),keyEquivalent:"c");edit.addItem(withTitle:model.text("粘贴"),action:#selector(NSText.paste(_:)),keyEquivalent:"v");edit.addItem(withTitle:model.text("全选"),action:#selector(NSText.selectAll(_:)),keyEquivalent:"a")
        NSApp.mainMenu=menu
    }
    @objc func about(){model.showAbout=true}
    @objc func settings(){model.settings=true}
    @objc func openFile(){model.chooseFile()}
    @objc func export(){model.exportCSV()}
    func application(_ sender:NSApplication,openFiles filenames:[String]){if let file=filenames.first{model.audio?.analyze(URL(fileURLWithPath:file))};sender.reply(toOpenOrPrint:.success)}
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool{true}
    func applicationWillTerminate(_ notification:Notification){model.audio?.stop();model.persist()}
}
let app=NSApplication.shared
let delegate=AppDelegate();app.delegate=delegate;app.run()
