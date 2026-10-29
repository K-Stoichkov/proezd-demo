import SwiftUI
import CoreImage

@main
struct ProezdDemoApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

// MARK: - Модель

struct Ticket: Identifiable, Codable, Equatable {
    let id: String
    let route: String
    let transport: String
    let tariff: String
    let price: Int
    let ts: Date
}

// MARK: - Хранилище (UserDefaults)

@MainActor
final class TicketStore: ObservableObject {
    @Published var tickets: [Ticket] = [] { didSet { save() } }

    private let key = "busDemoTickets_v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let list = try? JSONDecoder().decode([Ticket].self, from: data) {
            tickets = list
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(tickets) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func add(route: String, transport: String, tariff: String, price: Int) -> Ticket {
        let t = Ticket(id: UUID().uuidString, route: route,
                       transport: transport, tariff: tariff,
                       price: price, ts: Date())
        tickets.insert(t, at: 0)
        return t
    }

    func remove(_ t: Ticket) {
        tickets.removeAll { $0.id == t.id }
    }

    func clear() { tickets.removeAll() }

    var totalSpent: Int { tickets.reduce(0) { $0 + $1.price } }
}

// MARK: - Корневое окно с табами

struct RootView: View {
    @StateObject private var store = TicketStore()
    @State private var tab = 0
    @State private var showingTicket: Ticket?

    var body: some View {
        TabView(selection: $tab) {
            PayScreen(store: store, buy: { t in
                showingTicket = t
            })
                .tabItem { Label("Оплата", systemImage: "ticket") }
                .tag(0)
            HistoryScreen(store: store, open: { t in
                showingTicket = t
            })
                .tabItem { Label("История", systemImage: "clock") }
                .tag(1)
        }
        .fullScreenCover(item: $showingTicket) { t in
            TicketScreen(ticket: t) { showingTicket = nil }
        }
    }
}

// MARK: - Экран оплаты

struct PayScreen: View {
    @ObservedObject var store: TicketStore
    let buy: (Ticket) -> Void

    @State private var route = "45"
    @State private var transport = "684AK04"
    @State private var tariffName = "Стандарт"
    @State private var price = 80
    @State private var paying = false
    @State private var routeError = false
    @State private var transportError = false

    private let tariffs: [(String, Int)] = [("Стандарт", 80), ("Детский", 40)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    card
                    payButton
                }
                .padding(.horizontal, 16)
            }
            .background(Color(white: 0.93))
            .navigationTitle("Оплата проезда")
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Данные поездки")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            field("Номер маршрута", text: $route, error: routeError) {
                TextField("45", text: $route)
                    .keyboardType(.numberPad)
                    .onChange(of: route) { v in
                        route = String(v.filter { $0.isNumber }.prefix(4))
                    }
            }

            field("Номер транспорта", text: $transport, error: transportError) {
                TextField("684AK04", text: $transport)
                    .textInputAutocapitalization(.characters)
                    .disableAutocorrection(true)
                    .onChange(of: transport) { v in
                        transport = String(v.uppercased().prefix(8))
                    }
                Button {
                    let letters = "ABEFHKMOPRTX"
                    var s = ""
                    for _ in 0..<3 { s += String(Int.random(in: 0...9)) }
                    s += String(letters.randomElement()!)
                    s += String(letters.randomElement()!)
                    for _ in 0..<2 { s += String(Int.random(in: 0...9)) }
                    transport = s
                } label: {
                    Image(systemName: "dice")
                }
            }

            Text("Тариф")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(tariffs, id: \.0) { name, p in
                    Button {
                        tariffName = name; price = p
                    } label: {
                        Text("\(name) / \(p) ₸")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(tariffName == name ? Color.white : Color(hex: "33355a"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(tariffName == name ? Color(hex: "1b1cb4") : Color(hex: "f2f3f8"))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(.white)
            .shadow(color: .black.opacity(0.06), radius: 12, y: 4))
    }

    private func field(_ label: String, text: Binding<String>, error: Bool,
                       @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                content()
                    .font(.body.weight(.semibold))
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14)
                        .fill(error ? Color(hex: "fde8ec") : Color(hex: "f2f3f8")))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(error ? Color(hex: "e0455f") : Color(hex: "dfe1ea"), lineWidth: 1.5))
            }
        }
    }

    private var payButton: some View {
        Button {
            guard !route.isEmpty else { routeError = true; return }
            guard !transport.isEmpty else { transportError = true; return }
            routeError = false; transportError = false
            paying = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                paying = false
                buy(store.add(route: route, transport: transport,
                              tariff: tariffName, price: price))
            }
        } label: {
            VStack(spacing: 2) {
                Text("Оплатить проезд")
                    .font(.body.weight(.bold))
                Text("\(tariffName) / \(price) ₸")
                    .font(.caption.weight(.semibold))
                    .opacity(0.8)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: "1b1cb4")))
            .shadow(color: Color(hex: "1b1cb4").opacity(0.3), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
        .overlay {
            if paying {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.55))
                    HStack(spacing: 10) {
                        ProgressView().tint(.white)
                        Text("Списание средств…").foregroundStyle(.white).font(.footnote.bold())
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.15)))
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}

// MARK: - Генерация QR

func qrImage(_ text: String, scale: CGFloat = 8) -> UIImage? {
    let data = Data(text.utf8)
    guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
    filter.setValue(data, forKey: "inputMessage")
    filter.setValue("M", forKey: "inputCorrectionLevel")
    guard let output = filter.outputImage else { return nil }
    let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    guard let cg = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
    return UIImage(cgImage: cg)
}

// MARK: - Экран билета

struct TicketScreen: View {
    let ticket: Ticket
    let close: () -> Void

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                Card
                    .padding(.top, max(geo.safeAreaInsets.top, 24))
                    .padding(.bottom, 60)
            }
        }
        .background(Color(hex: "c9cbd6").ignoresSafeArea())
    }

    private var dateShort: String {
        let d = ticket.ts
        return String(format: "%02d.%02d.%d", d.day, d.month, d.year)
    }
    private var timeShort: String {
        let d = ticket.ts
        return String(format: "%02d:%02d", d.hour, d.minute)
    }

    private var Card: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                // QR
                Group {
                    if let img = qrImage(qrText) {
                        Image(uiImage: img)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 18).fill(.white))
                .frame(width: 190)
                .padding(.top, 30)

                Text("Номер маршрута")
                    .font(.system(size: 27, weight: .regular))
                    .padding(.top, 34)
                Text("№ \(ticket.route)")
                    .font(.system(size: 32, weight: .bold))
                    .padding(.bottom, 8)

                // перфорация
                TearLine()

                Text("Оплачено:")
                    .font(.system(size: 20, weight: .medium))
                HStack(spacing: 2) {
                    seg(dateShort)
                    seg(timeShort, divider: true)
                }
                .background(RoundedRectangle(cornerRadius: 13).fill(Color.white.opacity(0.17)))
                .padding(.vertical, 12)

                Text("Мой билет:")
                    .font(.system(size: 20, weight: .medium))
                Text("\(ticket.tariff) / \(ticket.price) ₸")
                    .font(.system(size: 17, weight: .bold))
                    .padding(.vertical, 11).padding(.horizontal, 30)
                    .background(RoundedRectangle(cornerRadius: 13).fill(Color.white.opacity(0.17)))
                    .padding(.vertical, 12)

                Text("Номер транспорта:")
                    .font(.system(size: 20, weight: .medium))
                Text(ticket.transport)
                    .font(.system(size: 26, weight: .bold))
                    .padding(.top, 4)

                Text("Демо-макет — не чек об оплате")
                    .font(.caption2)
                    .foregroundStyle(Color.white.opacity(0.8))
                    .padding(.top, 18)
            }
            .padding(22)
            .background(RoundedRectangle(cornerRadius: 30).fill(Color(hex: "1b1cb4")))
            .shadow(color: .black.opacity(0.3), radius: 30, y: 24)
            .padding(.horizontal, 30)

            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.white.opacity(0.22)))
            }
            .padding(.trailing, 42)
        }
        .padding(.horizontal, 6)
    }

    private var qrText: String {
        "DEMO · НЕ БИЛЕТ | \(ticket.route) | \(ticket.transport) | \(dateShort) \(timeShort) | \(ticket.price)₸"
    }

    private func seg(_ text: String, divider: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 17, weight: .bold))
            .padding(.horizontal, 26)
            .padding(.vertical, 11)
            .overlay(alignment: .leading) {
                if divider {
                    Rectangle()
                        .fill(Color(hex: "06063c").opacity(0.32))
                        .frame(width: 2)
                }
            }
    }
}

/// Линия отрыва с вырезами-полукругами по краям
struct TearLine: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                DashedLine()
                    .stroke(style: StrokeStyle(lineWidth: 3, dash: [6, 5]))
                    .foregroundStyle(Color(hex: "080846").opacity(0.45))
                    .padding(.horizontal, 22)
                Circle()
                    .fill(Color(hex: "c9cbd6"))
                    .frame(width: 30, height: 30)
                    .offset(x: -geo.size.width / 2 - 15)
                Circle()
                    .fill(Color(hex: "c9cbd6"))
                    .frame(width: 30, height: 30)
                    .offset(x: geo.size.width / 2 + 15)
            }
        }
        .frame(height: 30)
        .padding(.vertical, 10)
    }
}

struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

// MARK: - История

struct HistoryScreen: View {
    @ObservedObject var store: TicketStore
    let open: (Ticket) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if store.tickets.isEmpty {
                    VStack(spacing: 8) {
                        Text("Пока нет билетов")
                            .font(.headline)
                        Text("Купите первый на вкладке «Оплата»")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    List {
                        Section {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Потрачено")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    HStack(spacing: 2) {
                                        Text(store.totalSpent, format: .number)
                                        Text(" ₸")
                                    }
                                    .font(.title2.weight(.heavy))
                                    .foregroundStyle(Color(hex: "1b1cb4"))
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Поездок")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Text("\(store.tickets.count)")
                                        .font(.title3.weight(.bold))
                                }
                            }
                        }
                        ForEach(store.tickets) { t in
                            Button { open(t) } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("№ \(t.route) · \(t.transport)")
                                            .font(.body.weight(.bold))
                                            .foregroundStyle(.primary)
                                        Text("\(t.dateShort) · \(t.timeShort) · \(t.tariff)")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("\(t.price) ₸")
                                        .font(.body.weight(.heavy))
                                        .foregroundStyle(Color(hex: "1b1cb4"))
                                    Image(systemName: "chevron.right")
                                        .font(.footnote)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    store.remove(t)
                                } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("История билетов")
            .toolbar {
                if !store.tickets.isEmpty {
                    ToolbarItem(placement: .bottomBar) {
                        Button("Очистить историю", role: .destructive) {
                            store.clear()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Хелперы

extension Date {
    var day: Int { Calendar.current.component(.day, from: self) }
    var month: Int { Calendar.current.component(.month, from: self) }
    var year: Int { Calendar.current.component(.year, from: self) }
    var hour: Int { Calendar.current.component(.hour, from: self) }
    var minute: Int { Calendar.current.component(.minute, from: self) }
    var dateShort: String { String(format: "%02d.%02d.%d", day, month, year) }
    var timeShort: String { String(format: "%02d:%02d", hour, minute) }
}

extension Color {
    init(hex: String) {
        var v = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        if v.count == 3 { v = v.map { "\($0)\($0)" }.joined() }
        var n: UInt64 = 0
        Scanner(string: v).scanHexInt64(&n)
        self.init(.sRGB,
                  red: Double((n >> 16) & 255) / 255,
                  green: Double((n >> 8) & 255) / 255,
                  blue: Double(n & 255) / 255,
                  opacity: 1)
    }
}
