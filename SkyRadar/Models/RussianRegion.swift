//
//  RussianRegion.swift
//  SkyRadar
//
//  Справочник 89 субъектов РФ и их ключевых городов, совпадающий с фидом.
//

import Foundation

/// Субъект РФ: идентификатор фида, название, псевдонимы и города.
nonisolated struct RussianRegion: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let aliases: [String]
    let cities: [String]
    let latitude: Double
    let longitude: Double
    let radiusKm: Double

    /// Регион в формате подписки на сводки.
    var monitored: MonitoredRegion {
        let words = ([name.lowercased()] + aliases + cities.map { $0.lowercased() })
        return MonitoredRegion(
            id: id,
            name: name,
            keywords: Array(Set(words)).sorted(),
            latitude: latitude,
            longitude: longitude,
            radiusKm: radiusKm
        )
    }

    /// Город из справочника, если запрос совпал с ним, а не только с названием субъекта.
    func matchedCity(for query: String) -> String? {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard needle.count >= 2 else { return nil }
        return cities.first { $0.lowercased().contains(needle) }
    }

    static let catalog: [RussianRegion] = [
        RussianRegion(id: "adygea", name: "Республика Адыгея", aliases: ["адыгея"], cities: ["Майкоп"], latitude: 44.6098, longitude: 40.1006, radiusKm: 40),
        RussianRegion(id: "altai", name: "Республика Алтай", aliases: ["республика алтай", "горный алтай"], cities: ["Горно-Алтайск"], latitude: 51.9581, longitude: 85.9603, radiusKm: 80),
        RussianRegion(id: "bashkortostan", name: "Республика Башкортостан", aliases: ["башкортостан", "башкирия"], cities: ["Уфа", "Стерлитамак", "Салават", "Нефтекамск"], latitude: 54.7388, longitude: 55.9721, radiusKm: 90),
        RussianRegion(id: "buryatia", name: "Республика Бурятия", aliases: ["бурятия"], cities: ["Улан-Удэ"], latitude: 51.8335, longitude: 107.5841, radiusKm: 90),
        RussianRegion(id: "chechnya", name: "Чеченская Республика", aliases: ["чеченская республика", "чечня"], cities: ["Грозный"], latitude: 43.318, longitude: 45.6982, radiusKm: 50),
        RussianRegion(id: "chuvashia", name: "Чувашская Республика", aliases: ["чувашская республика", "чувашия"], cities: ["Чебоксары"], latitude: 56.1439, longitude: 47.2489, radiusKm: 50),
        RussianRegion(id: "crimea", name: "Республика Крым", aliases: ["крым", "автономная республика крым"], cities: ["Симферополь", "Ялта", "Керчь", "Евпатория", "Феодосия", "Джанкой", "Алушта", "Бахчисарай", "Судак", "Армянск", "Красноперекопск"], latitude: 44.9521, longitude: 34.1024, radiusKm: 80),
        RussianRegion(id: "dagestan", name: "Республика Дагестан", aliases: ["дагестан"], cities: ["Махачкала", "Дербент", "Хасавюрт", "Каспийск"], latitude: 42.9849, longitude: 47.5047, radiusKm: 80),
        RussianRegion(id: "dnr", name: "Донецкая Народная Республика", aliases: ["днр"], cities: ["Донецк", "Мариуполь", "Горловка", "Макеевка"], latitude: 48.0159, longitude: 37.8028, radiusKm: 70),
        RussianRegion(id: "ingushetia", name: "Республика Ингушетия", aliases: ["ингушетия"], cities: ["Назрань", "Магас"], latitude: 43.1667, longitude: 44.8167, radiusKm: 30),
        RussianRegion(id: "kabardino-balkaria", name: "Кабардино-Балкарская Республика", aliases: ["кабардино-балкарская республика", "кабардино-балкария", "кбр"], cities: ["Нальчик"], latitude: 43.4981, longitude: 43.6189, radiusKm: 40),
        RussianRegion(id: "kalmykia", name: "Республика Калмыкия", aliases: ["калмыкия"], cities: ["Элиста"], latitude: 46.3078, longitude: 44.2558, radiusKm: 70),
        RussianRegion(id: "karachay-cherkessia", name: "Карачаево-Черкесская Республика", aliases: ["карачаево-черкесская республика", "карачаево-черкесия", "кчр"], cities: ["Черкесск"], latitude: 44.2269, longitude: 42.0468, radiusKm: 40),
        RussianRegion(id: "karelia", name: "Республика Карелия", aliases: ["карелия"], cities: ["Петрозаводск"], latitude: 61.7849, longitude: 34.3469, radiusKm: 90),
        RussianRegion(id: "khakassia", name: "Республика Хакасия", aliases: ["хакасия"], cities: ["Абакан"], latitude: 53.7212, longitude: 91.4424, radiusKm: 60),
        RussianRegion(id: "komi", name: "Республика Коми", aliases: ["коми"], cities: ["Сыктывкар"], latitude: 61.6688, longitude: 50.8364, radiusKm: 100),
        RussianRegion(id: "lnr", name: "Луганская Народная Республика", aliases: ["лнр"], cities: ["Луганск", "Алчевск", "Северодонецк", "Брянка", "Стаханов"], latitude: 48.574, longitude: 39.3078, radiusKm: 70),
        RussianRegion(id: "mari-el", name: "Республика Марий Эл", aliases: ["марий эл"], cities: ["Йошкар-Ола"], latitude: 56.6344, longitude: 47.8998, radiusKm: 50),
        RussianRegion(id: "mordovia", name: "Республика Мордовия", aliases: ["мордовия"], cities: ["Саранск"], latitude: 54.1838, longitude: 45.1749, radiusKm: 50),
        RussianRegion(id: "north-ossetia", name: "Республика Северная Осетия — Алания", aliases: ["северная осетия", "алания", "северная осетия - алания"], cities: ["Владикавказ"], latitude: 43.0246, longitude: 44.6818, radiusKm: 40),
        RussianRegion(id: "sakha", name: "Республика Саха (Якутия)", aliases: ["республика саха", "якутия"], cities: ["Якутск"], latitude: 62.0355, longitude: 129.6755, radiusKm: 150),
        RussianRegion(id: "tatarstan", name: "Республика Татарстан", aliases: ["татарстан"], cities: ["Казань", "Елабуга", "Нижнекамск", "Альметьевск", "Набережные Челны", "Зеленодольск"], latitude: 55.7961, longitude: 49.1064, radiusKm: 90),
        RussianRegion(id: "tuva", name: "Республика Тыва", aliases: ["тыва", "тува"], cities: ["Кызыл"], latitude: 51.7191, longitude: 94.4378, radiusKm: 80),
        RussianRegion(id: "udmurtia", name: "Удмуртская Республика", aliases: ["удмуртская республика", "удмуртия"], cities: ["Ижевск"], latitude: 56.8527, longitude: 53.2115, radiusKm: 60),
        RussianRegion(id: "altai-krai", name: "Алтайский край", aliases: [], cities: ["Барнаул", "Бийск", "Рубцовск"], latitude: 53.3606, longitude: 83.7636, radiusKm: 100),
        RussianRegion(id: "zabaykalsky-krai", name: "Забайкальский край", aliases: ["забайкалье"], cities: ["Чита"], latitude: 52.0515, longitude: 113.4712, radiusKm: 120),
        RussianRegion(id: "kamchatka-krai", name: "Камчатский край", aliases: ["камчатка"], cities: ["Петропавловск-Камчатский"], latitude: 53.0241, longitude: 158.6436, radiusKm: 120),
        RussianRegion(id: "krasnodar-krai", name: "Краснодарский край", aliases: ["кубань"], cities: ["Краснодар", "Сочи", "Новороссийск", "Туапсе", "Анапа", "Геленджик", "Ейск", "Армавир", "Темрюк", "Крымск", "Тихорецк"], latitude: 45.0355, longitude: 38.9753, radiusKm: 100),
        RussianRegion(id: "krasnoyarsk-krai", name: "Красноярский край", aliases: [], cities: ["Красноярск", "Норильск", "Ачинск"], latitude: 56.0153, longitude: 92.8932, radiusKm: 150),
        RussianRegion(id: "perm-krai", name: "Пермский край", aliases: [], cities: ["Пермь", "Березники"], latitude: 58.0105, longitude: 56.2502, radiusKm: 100),
        RussianRegion(id: "primorsky-krai", name: "Приморский край", aliases: ["приморье"], cities: ["Владивосток", "Находка", "Уссурийск"], latitude: 43.1155, longitude: 131.8855, radiusKm: 110),
        RussianRegion(id: "stavropol-krai", name: "Ставропольский край", aliases: ["ставрополье"], cities: ["Ставрополь", "Пятигорск", "Кисловодск", "Невинномысск", "Ессентуки", "Минеральные Воды"], latitude: 45.0445, longitude: 41.969, radiusKm: 80),
        RussianRegion(id: "khabarovsk-krai", name: "Хабаровский край", aliases: [], cities: ["Хабаровск", "Комсомольск-на-Амуре"], latitude: 48.4827, longitude: 135.0838, radiusKm: 120),
        RussianRegion(id: "amur-oblast", name: "Амурская область", aliases: [], cities: ["Благовещенск"], latitude: 50.2907, longitude: 127.5272, radiusKm: 90),
        RussianRegion(id: "arkhangelsk-oblast", name: "Архангельская область", aliases: [], cities: ["Архангельск", "Северодвинск"], latitude: 64.5399, longitude: 40.5152, radiusKm: 100),
        RussianRegion(id: "astrakhan-oblast", name: "Астраханская область", aliases: [], cities: ["Астрахань"], latitude: 46.3497, longitude: 48.0408, radiusKm: 70),
        RussianRegion(id: "belgorod-oblast", name: "Белгородская область", aliases: [], cities: ["Белгород", "Шебекино", "Грайворон", "Валуйки", "Старый Оскол", "Алексеевка"], latitude: 50.5951, longitude: 36.5873, radiusKm: 70),
        RussianRegion(id: "bryansk-oblast", name: "Брянская область", aliases: [], cities: ["Брянск", "Клинцы", "Стародуб", "Дятьково", "Унеча", "Почеп", "Трубчевск", "Суземка", "Севск"], latitude: 53.2521, longitude: 34.3717, radiusKm: 65),
        RussianRegion(id: "vladimir-oblast", name: "Владимирская область", aliases: [], cities: ["Владимир", "Ковров", "Муром"], latitude: 56.129, longitude: 40.4066, radiusKm: 55),
        RussianRegion(id: "volgograd-oblast", name: "Волгоградская область", aliases: [], cities: ["Волгоград", "Волжский", "Камышин", "Урюпинск", "Михайловка"], latitude: 48.708, longitude: 44.5133, radiusKm: 90),
        RussianRegion(id: "vologda-oblast", name: "Вологодская область", aliases: [], cities: ["Вологда", "Череповец"], latitude: 59.2205, longitude: 39.8915, radiusKm: 80),
        RussianRegion(id: "voronezh-oblast", name: "Воронежская область", aliases: [], cities: ["Воронеж", "Борисоглебск", "Россошь", "Лиски", "Острогожск"], latitude: 51.6608, longitude: 39.2003, radiusKm: 75),
        RussianRegion(id: "ivanovo-oblast", name: "Ивановская область", aliases: [], cities: ["Иваново"], latitude: 57.0003, longitude: 40.9739, radiusKm: 50),
        RussianRegion(id: "irkutsk-oblast", name: "Иркутская область", aliases: [], cities: ["Иркутск", "Братск", "Ангарск"], latitude: 52.287, longitude: 104.305, radiusKm: 120),
        RussianRegion(id: "kaliningrad-oblast", name: "Калининградская область", aliases: [], cities: ["Калининград"], latitude: 54.7104, longitude: 20.4522, radiusKm: 50),
        RussianRegion(id: "kaluga-oblast", name: "Калужская область", aliases: [], cities: ["Калуга", "Обнинск"], latitude: 54.5293, longitude: 36.2754, radiusKm: 55),
        RussianRegion(id: "kemerovo-oblast", name: "Кемеровская область", aliases: ["кузбасс", "кемеровская область — кузбасс"], cities: ["Кемерово", "Новокузнецк", "Прокопьевск"], latitude: 55.3543, longitude: 86.0884, radiusKm: 80),
        RussianRegion(id: "kirov-oblast", name: "Кировская область", aliases: [], cities: ["Киров"], latitude: 58.6036, longitude: 49.668, radiusKm: 80),
        RussianRegion(id: "kostroma-oblast", name: "Костромская область", aliases: [], cities: ["Кострома"], latitude: 57.7679, longitude: 40.9269, radiusKm: 60),
        RussianRegion(id: "kurgan-oblast", name: "Курганская область", aliases: [], cities: ["Курган"], latitude: 55.4444, longitude: 65.3161, radiusKm: 60),
        RussianRegion(id: "kursk-oblast", name: "Курская область", aliases: [], cities: ["Курск", "Суджа", "Рыльск", "Льгов", "Курчатов"], latitude: 51.7373, longitude: 36.1874, radiusKm: 65),
        RussianRegion(id: "leningrad-oblast", name: "Ленинградская область", aliases: ["ленобласть"], cities: ["Гатчина", "Выборг", "Тихвин", "Сосновый Бор", "Кингисепп", "Волхов"], latitude: 59.5764, longitude: 30.1283, radiusKm: 90),
        RussianRegion(id: "lipetsk-oblast", name: "Липецкая область", aliases: [], cities: ["Липецк", "Елец"], latitude: 52.6031, longitude: 39.5708, radiusKm: 55),
        RussianRegion(id: "magadan-oblast", name: "Магаданская область", aliases: [], cities: ["Магадан"], latitude: 59.5638, longitude: 150.8035, radiusKm: 90),
        RussianRegion(id: "moscow-oblast", name: "Московская область", aliases: ["подмосковье"], cities: ["Химки", "Подольск", "Мытищи", "Балашиха", "Королёв", "Люберцы", "Одинцово", "Красногорск", "Коломна", "Серпухов", "Электросталь", "Домодедово", "Жуковский", "Дмитров", "Клин"], latitude: 55.583, longitude: 37.666, radiusKm: 80),
        RussianRegion(id: "murmansk-oblast", name: "Мурманская область", aliases: [], cities: ["Мурманск"], latitude: 68.9585, longitude: 33.0827, radiusKm: 90),
        RussianRegion(id: "nizhny-novgorod-oblast", name: "Нижегородская область", aliases: [], cities: ["Нижний Новгород", "Дзержинск", "Арзамас", "Саров", "Кстово"], latitude: 56.2965, longitude: 43.9361, radiusKm: 80),
        RussianRegion(id: "novgorod-oblast", name: "Новгородская область", aliases: [], cities: ["Великий Новгород"], latitude: 58.5215, longitude: 31.2755, radiusKm: 60),
        RussianRegion(id: "novosibirsk-oblast", name: "Новосибирская область", aliases: [], cities: ["Новосибирск", "Бердск"], latitude: 55.0084, longitude: 82.9357, radiusKm: 90),
        RussianRegion(id: "omsk-oblast", name: "Омская область", aliases: [], cities: ["Омск"], latitude: 54.9885, longitude: 73.3242, radiusKm: 80),
        RussianRegion(id: "orenburg-oblast", name: "Оренбургская область", aliases: [], cities: ["Оренбург", "Орск"], latitude: 51.7682, longitude: 55.097, radiusKm: 90),
        RussianRegion(id: "oryol-oblast", name: "Орловская область", aliases: [], cities: ["Орёл", "Ливны", "Мценск"], latitude: 52.9651, longitude: 36.0785, radiusKm: 55),
        RussianRegion(id: "penza-oblast", name: "Пензенская область", aliases: [], cities: ["Пенза"], latitude: 53.1959, longitude: 45.0183, radiusKm: 55),
        RussianRegion(id: "pskov-oblast", name: "Псковская область", aliases: [], cities: ["Псков", "Великие Луки"], latitude: 57.8194, longitude: 28.3318, radiusKm: 60),
        RussianRegion(id: "rostov-oblast", name: "Ростовская область", aliases: [], cities: ["Ростов-на-Дону", "Таганрог", "Шахты", "Волгодонск", "Морозовск", "Миллерово", "Новочеркасск", "Батайск", "Азов", "Каменск-Шахтинский", "Гуково"], latitude: 47.2357, longitude: 39.7015, radiusKm: 85),
        RussianRegion(id: "ryazan-oblast", name: "Рязанская область", aliases: [], cities: ["Рязань"], latitude: 54.6296, longitude: 39.7425, radiusKm: 60),
        RussianRegion(id: "samara-oblast", name: "Самарская область", aliases: [], cities: ["Самара", "Тольятти", "Сызрань", "Новокуйбышевск", "Чапаевск"], latitude: 53.1959, longitude: 50.1002, radiusKm: 75),
        RussianRegion(id: "saratov-oblast", name: "Саратовская область", aliases: [], cities: ["Саратов", "Энгельс", "Балаково", "Балашов", "Вольск"], latitude: 51.5336, longitude: 46.0343, radiusKm: 80),
        RussianRegion(id: "sakhalin-oblast", name: "Сахалинская область", aliases: ["сахалин"], cities: ["Южно-Сахалинск"], latitude: 46.9591, longitude: 142.738, radiusKm: 80),
        RussianRegion(id: "sverdlovsk-oblast", name: "Свердловская область", aliases: [], cities: ["Екатеринбург", "Нижний Тагил", "Каменск-Уральский", "Первоуральск"], latitude: 56.8389, longitude: 60.6057, radiusKm: 100),
        RussianRegion(id: "smolensk-oblast", name: "Смоленская область", aliases: [], cities: ["Смоленск", "Вязьма", "Рославль", "Ярцево", "Сафоново"], latitude: 54.7826, longitude: 32.0453, radiusKm: 60),
        RussianRegion(id: "tambov-oblast", name: "Тамбовская область", aliases: [], cities: ["Тамбов", "Мичуринск"], latitude: 52.7212, longitude: 41.4523, radiusKm: 55),
        RussianRegion(id: "tver-oblast", name: "Тверская область", aliases: [], cities: ["Тверь"], latitude: 56.8587, longitude: 35.9176, radiusKm: 70),
        RussianRegion(id: "tomsk-oblast", name: "Томская область", aliases: [], cities: ["Томск"], latitude: 56.4846, longitude: 84.9476, radiusKm: 80),
        RussianRegion(id: "tula-oblast", name: "Тульская область", aliases: [], cities: ["Тула", "Новомосковск", "Алексин", "Щёкино", "Узловая"], latitude: 54.1931, longitude: 37.6173, radiusKm: 50),
        RussianRegion(id: "tyumen-oblast", name: "Тюменская область", aliases: [], cities: ["Тюмень", "Тобольск"], latitude: 57.153, longitude: 65.5343, radiusKm: 80),
        RussianRegion(id: "ulyanovsk-oblast", name: "Ульяновская область", aliases: [], cities: ["Ульяновск", "Димитровград"], latitude: 54.3142, longitude: 48.4031, radiusKm: 60),
        RussianRegion(id: "chelyabinsk-oblast", name: "Челябинская область", aliases: [], cities: ["Челябинск", "Магнитогорск", "Златоуст", "Миасс"], latitude: 55.1644, longitude: 61.4368, radiusKm: 80),
        RussianRegion(id: "yaroslavl-oblast", name: "Ярославская область", aliases: [], cities: ["Ярославль", "Рыбинск", "Ростов Великий"], latitude: 57.6261, longitude: 39.8845, radiusKm: 60),
        RussianRegion(id: "kherson-oblast", name: "Херсонская область", aliases: [], cities: ["Херсон", "Геническ", "Скадовск"], latitude: 46.6354, longitude: 32.6169, radiusKm: 70),
        RussianRegion(id: "zaporizhzhia-oblast", name: "Запорожская область", aliases: ["запорожье"], cities: ["Запорожье", "Мелитополь", "Бердянск", "Энергодар"], latitude: 47.8388, longitude: 35.1396, radiusKm: 70),
        RussianRegion(id: "moscow", name: "Москва", aliases: ["город москва", "мск"], cities: ["Москва"], latitude: 55.7558, longitude: 37.6173, radiusKm: 30),
        RussianRegion(id: "saint-petersburg", name: "Санкт-Петербург", aliases: ["петербург", "спб", "санкт петербург"], cities: ["Санкт-Петербург"], latitude: 59.9343, longitude: 30.3351, radiusKm: 28),
        RussianRegion(id: "sevastopol", name: "Севастополь", aliases: ["город севастополь"], cities: ["Севастополь"], latitude: 44.6166, longitude: 33.5254, radiusKm: 25),
        RussianRegion(id: "jewish-autonomous-oblast", name: "Еврейская автономная область", aliases: ["еао"], cities: ["Биробиджан"], latitude: 48.7946, longitude: 132.9218, radiusKm: 50),
        RussianRegion(id: "nenets-ao", name: "Ненецкий автономный округ", aliases: ["нао"], cities: ["Нарьян-Мар"], latitude: 67.6381, longitude: 53.0069, radiusKm: 80),
        RussianRegion(id: "khanty-mansi-ao", name: "Ханты-Мансийский автономный округ — Югра", aliases: ["хмао", "югра", "ханты-мансийский автономный округ"], cities: ["Сургут", "Нижневартовск", "Нефтеюганск", "Ханты-Мансийск"], latitude: 61.0032, longitude: 69.0189, radiusKm: 120),
        RussianRegion(id: "chukotka-ao", name: "Чукотский автономный округ", aliases: ["чукотка"], cities: ["Анадырь"], latitude: 64.7337, longitude: 177.4968, radiusKm: 120),
        RussianRegion(id: "yamalo-nenets-ao", name: "Ямало-Ненецкий автономный округ", aliases: ["янао", "ямал"], cities: ["Салехард", "Новый Уренгой", "Ноябрьск", "Надым"], latitude: 66.5299, longitude: 66.6145, radiusKm: 120),
    ]

    static var presets: [MonitoredRegion] { catalog.map(\.monitored) }
}

