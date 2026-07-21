import Foundation

enum DefaultContent {
    static func projects(locale: Locale = .current) -> [ChecklistProject] {
        if locale.identifier.lowercased().hasPrefix("zh") {
            return [chineseTravelChecklist]
        }
        return [englishTravelChecklist]
    }

    static let englishTravelChecklist = ChecklistProject(
        title: "Travel Checklist",
        items: [
            "Passport",
            "Drivers license or other official ID",
            "Visa (if necessary)",
            "Passport scan (don't forget to email to yourself if lost)",
            "Address book and emergency numbers and contact details",
            "Travel tickets (airplane, train, bus)",
            "Directions",
            "Hotel contact details",
            "Map and guide book",
            "Cash in foreign currency (if applicable)",
            "Get a Credit card, debit card or ATM card",
        ].map { ChecklistItem(title: $0) }
    )

    static let chineseTravelChecklist = ChecklistProject(
        title: "旅行清单",
        items: [
            "身份证、护照",
            "机票、旅游预订等确认函（打印）",
            "酒店确认函（打印）",
            "现金、银行卡、信用卡",
            "行程表、地图、攻略地址",
            "纸笔（记录旅游费用）",
            "手机、移动充、数据线",
            "相机、iPad、转换插头",
            "消毒纸巾、纸巾",
            "压缩面巾、压缩毛巾",
            "厕所垫、保温杯",
            "旅行牙刷套装、牙线",
            "近视镜、太阳眼镜",
            "感冒药、肠胃药、止血贴、防蚊贴、双飞人",
            "密封袋、保鲜袋各2",
            "环保袋1个",
        ].map { ChecklistItem(title: $0) }
    )
}
