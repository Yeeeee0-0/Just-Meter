import Foundation
import SwiftUI
@main struct LayoutTests {
    static func main() {
        let standard=MeterLayout.standard
        precondition(standard.widgets.count==4 && standard.widgets.allSatisfy{$0.width==1 && $0.height==1})
        precondition(standard==MeterLayout.standard,"Built-in widget identities must stay stable across refreshes")
        var widgets=standard.widgets
        widgets[0].width=2;widgets[0].height=2;widgets[1].height=2
        var occupied=Set<Int>()
        for item in pack(widgets) {
            precondition(item.column+item.widget.width<=2)
            for row in item.row..<(item.row+item.widget.height){for col in item.column..<(item.column+item.widget.width){precondition(occupied.insert(row*2+col).inserted,"Widgets overlap")}}
        }
        var p=Preferences();p.layouts=[standard,MeterLayout(name:"Invalid",widgets:[Widget(.peaks)])];p.layouts[1].widgets[0].width=100;p.layouts[1].widgets[0].height=0;p.layouts[1].widgets[0].fields=["invalid"];p.selected="missing";p.transparency=999;p.sanitize()
        precondition(p.layouts.count==1 && p.layouts[0].widgets[0].width==2 && p.layouts[0].widgets[0].height==1)
        precondition(p.layouts[0].widgets[0].fields==["True Peak"] && p.selected=="default" && p.transparency==85)
        let data=try! JSONEncoder().encode(p);let decoded=try! JSONDecoder().decode(Preferences.self,from:data)
        precondition(decoded.layouts==p.layouts)
        var legacy=try! JSONSerialization.jsonObject(with:data) as! [String:Any]
        legacy.removeValue(forKey:"interfaceScale")
        let restored=try! JSONDecoder().decode(Preferences.self,from:JSONSerialization.data(withJSONObject:legacy))
        precondition(restored.scale==1 && restored.layouts==p.layouts,"Old layouts must survive the scale upgrade")
        for value in Preferences.scales {var scaled=restored;scaled.scale=value;scaled.sanitize();let roundTrip=try! JSONDecoder().decode(Preferences.self,from:JSONEncoder().encode(scaled));precondition(roundTrip.scale==value)}
        var invalid=restored;invalid.scale=0;invalid.sanitize();precondition(invalid.scale==1)
        // Language upgrades must preserve existing custom layouts and measurement settings.
        var languageState=restored
        languageState.layouts=[MeterLayout(name:"My mix {0}",widgets:standard.widgets)]
        languageState.selected=languageState.layouts[0].id;languageState.unit="LU";languageState.reference = -23
        languageState.scale=0.75;languageState.theme="dark"
        let savedLayouts=languageState.layouts
        for language in AppLanguage.allCases {
            languageState.interfaceLanguage=language.rawValue;languageState.sanitize()
            let reloaded=try! JSONDecoder().decode(Preferences.self,from:JSONEncoder().encode(languageState))
            precondition(reloaded.language==language && reloaded.layouts==savedLayouts && reloaded.selected==savedLayouts[0].id)
            precondition(reloaded.reference == -23 && reloaded.unit=="LU" && reloaded.scale==0.75 && reloaded.theme=="dark")
        }
        var oldState=try! JSONSerialization.jsonObject(with:JSONEncoder().encode(languageState)) as! [String:Any]
        oldState.removeValue(forKey:"interfaceLanguage")
        let upgraded=try! JSONDecoder().decode(Preferences.self,from:JSONSerialization.data(withJSONObject:oldState))
        precondition(upgraded.interfaceLanguage==nil && upgraded.layouts==savedLayouts && upgraded.unit=="LU")
        oldState["interfaceLanguage"]="unsupported"
        var unsupported=try! JSONDecoder().decode(Preferences.self,from:JSONSerialization.data(withJSONObject:oldState));unsupported.sanitize()
        precondition(unsupported.interfaceLanguage==nil && unsupported.layouts==savedLayouts)
        precondition(AppLanguage.preferred(["zh-Hant-TW"]) == .chinese && AppLanguage.preferred(["fr-FR"]) == .english)
        let status=LocalizedMessage("{0} · 分析完成",arguments:["Mix {0}.wav"])
        precondition(status.resolved(in:.english)=="Mix {0}.wav · Analysis complete")
        precondition(status.resolved(in:.chinese)=="Mix {0}.wav · 分析完成")
        // Keep field IDs language-independent so old plugin state still selects the same data.
        for kind in WidgetKind.allCases {
            for key in [kind.title]+kind.fields where key.range(of:"[\\p{Han}]",options:.regularExpression) != nil {
                precondition(AppLanguage.english.text(key) != key,"Missing English widget label: \(key)")
            }
        }
        print("PASS: language round-trip, legacy state migration, layout and measurement preference preservation, literal user names, widget translation coverage")
        print("PASS: stable default IDs, four 1x1 widgets, mixed-size packing without overlap, protected default, state validation and persistence round-trip")
    }
}
