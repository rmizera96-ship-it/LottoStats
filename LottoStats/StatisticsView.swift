import SwiftUI
import Combine

struct StatisticsView: View {
    @StateObject private var viewModel = StatisticsViewModel()
    
    private var selectedGameBinding: Binding<LottoGame> {
        Binding {
            viewModel.selectedGame
        } set: { game in
            Task {
                await viewModel.selectGame(game)
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                gamePickerSection
                
                if viewModel.isLoading && viewModel.stats == nil {
                    loadingSection
                } else if viewModel.stats == nil {
                    if let errorMessage = viewModel.errorMessage {
                        errorSection(message: errorMessage)
                    } else {
                        emptySection
                    }
                } else {
                    if let errorMessage = viewModel.errorMessage {
                        warningSection(message: errorMessage)
                    }

                    summaryCard
                    mostFrequentCard
                    leastFrequentCard
                    
                    if !viewModel.specialFrequencyItems.isEmpty {
                        specialNumbersCard
                    }
                }
            }
            .padding()
            .safeAreaPadding(.bottom, 120)
        }
        .background(AppTheme.screenBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.loadInitialData()
        }
    }
    
    private var headerSection: some View {
        ScreenHeader(
            title: "Statystyki",
            subtitle: "Sprawdź, które liczby pojawiały się najczęściej w analizowanym okresie.",
            icon: "chart.bar.fill",
            tint: viewModel.selectedGame.visualColor
        )
    }
    
    private var gamePickerSection: some View {
        GameSelector(
            games: LottoGame.allCases,
            selection: selectedGameBinding
        )
    }
    
    private var loadingSection: some View {
        StatisticsCard(tint: viewModel.selectedGame.visualColor) {
            HStack(spacing: 12) {
                ProgressView()
                
                Text("Ładowanie statystyk...")
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func errorSection(message: String) -> some View {
        StatisticsCard(tint: .red) {
            VStack(spacing: 14) {
                EmptyStateArtwork(
                    icon: "chart.bar.xaxis",
                    tint: .red,
                    size: 86
                )

                VStack(spacing: 6) {
                    Text("Nie udało się pobrać statystyk")
                        .font(.headline)

                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                retryButton
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func warningSection(message: String) -> some View {
        StatisticsCard(tint: .orange) {
            VStack(alignment: .leading, spacing: 10) {
                Label("Wyświetlam ostatnio zapisane dane", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                retryButton
            }
        }
    }

    private var retryButton: some View {
        Button {
            Task {
                await viewModel.retry()
            }
        } label: {
            Label("Spróbuj ponownie", systemImage: "arrow.clockwise")
                .fontWeight(.semibold)
        }
        .buttonStyle(
            PrimaryActionButtonStyle(
                tint: viewModel.selectedGame.visualColor,
                isEnabled: !viewModel.isLoading
            )
        )
        .disabled(viewModel.isLoading)
    }
    
    private var emptySection: some View {
        EmptyStateCard(
            title: "Brak statystyk",
            message: "Nie udało się pobrać statystyk dla wybranej gry.",
            icon: "chart.bar.doc.horizontal",
            tint: viewModel.selectedGame.visualColor
        )
    }
    
    private var summaryCard: some View {
        StatisticsCard(tint: viewModel.selectedGame.visualColor) {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(
                    title: "Podsumowanie",
                    subtitle: "Zakres danych wykorzystanych do analizy",
                    icon: "calendar.badge.clock",
                    tint: viewModel.selectedGame.visualColor
                )

                HStack(spacing: 12) {
                    StatisticSummaryTile(
                        title: "Liczba losowań",
                        value: viewModel.drawCountText,
                        icon: "number.circle.fill",
                        tint: viewModel.selectedGame.visualColor
                    )

                    StatisticSummaryTile(
                        title: "Źródło",
                        value: viewModel.dataSourceName,
                        icon: "checkmark.seal.fill",
                        tint: .green
                    )
                }

                Label(viewModel.periodText, systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var mostFrequentCard: some View {
        StatisticsCard(tint: viewModel.selectedGame.visualColor) {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(
                    title: "Najczęściej losowane",
                    subtitle: "Najwyższa liczba wystąpień",
                    icon: "flame.fill",
                    tint: .orange
                )

                FrequencyGrid(
                    items: viewModel.mostFrequentMainItems,
                    circleColor: viewModel.selectedGame.visualColor,
                    highlightsTopThree: true
                )
            }
        }
    }
    
    private var leastFrequentCard: some View {
        StatisticsCard(tint: Color(.systemGray)) {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(
                    title: "Najrzadziej losowane",
                    subtitle: "Najniższa liczba wystąpień",
                    icon: "snowflake",
                    tint: Color(.systemGray)
                )

                FrequencyGrid(
                    items: viewModel.leastFrequentMainItems,
                    circleColor: Color(.systemGray),
                    highlightsTopThree: false
                )
            }
        }
    }
    
    private var specialNumbersCard: some View {
        StatisticsCard(tint: .purple) {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(
                    title: viewModel.specialNumbersTitle,
                    subtitle: "Ranking liczb dodatkowych",
                    icon: "star.fill",
                    tint: .purple
                )

                FrequencyGrid(
                    items: viewModel.specialFrequencyItems,
                    circleColor: .purple,
                    highlightsTopThree: true
                )
            }
        }
    }
}

@MainActor
final class StatisticsViewModel: ObservableObject {
    @Published private(set) var selectedGame: LottoGame = .lotto
    @Published private(set) var stats: LottoFrequencyStats?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    
    private let repository: LottoRepository
    private var statsByGame: [LottoGame: LottoFrequencyStats] = [:]
    
    init() {
        self.repository = LottoRepository.shared
    }
    
    init(repository: LottoRepository) {
        self.repository = repository
    }
    
    var dataSourceName: String {
        repository.dataSourceName
    }
    
    var mostFrequentMainItems: [LottoFrequencyItem] {
        Array((stats?.mainNumbers ?? []).prefix(10))
    }
    
    var leastFrequentMainItems: [LottoFrequencyItem] {
        Array(stats?.mainNumbers ?? [])
            .sorted { first, second in
                if first.numberOfOccurrences == second.numberOfOccurrences {
                    return first.number < second.number
                }
                
                return first.numberOfOccurrences < second.numberOfOccurrences
            }
            .prefix(10)
            .map { $0 }
    }
    
    var specialFrequencyItems: [LottoFrequencyItem] {
        Array((stats?.specialNumbers ?? []).prefix(10))
    }
    
    var specialNumbersTitle: String {
        switch selectedGame {
        case .eurojackpot:
            return "Najczęściej losowane euroliczby"
        case .lotto:
            return "Najczęściej losowane liczby specjalne"
        case .miniLotto:
            return "Najczęściej losowane liczby specjalne"
        }
    }
    
    var drawCountText: String {
        let count = stats?.totalDraws ?? 0
        
        switch count {
        case 1:
            return "1 losowanie"
        case 2...4:
            return "\(count) losowania"
        default:
            return "\(count) losowań"
        }
    }
    
    var periodText: String {
        guard let stats else {
            return "Brak danych"
        }
        
        let start = AppFormatters.polishShortDate.string(from: stats.dateFrom)
        let end = AppFormatters.polishShortDate.string(from: stats.dateTo)
        
        return "\(start) – \(end)"
    }
    
    func loadInitialData() async {
        if stats == nil {
            await loadData(for: selectedGame)
        }
    }
    
    func selectGame(_ game: LottoGame) async {
        guard game != selectedGame || stats == nil else {
            return
        }

        selectedGame = game
        errorMessage = nil

        if let cachedStats = statsByGame[game] {
            stats = cachedStats
            return
        }

        stats = nil
        await loadData(for: game)
    }

    func retry() async {
        await loadData(for: selectedGame)
    }
    
    private func loadData(for game: LottoGame) async {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedStats = try await repository.fetchNumberFrequencyStats(for: game)

            if let fetchedStats {
                statsByGame[game] = fetchedStats

                if selectedGame == game {
                    stats = fetchedStats
                }
            } else {
                errorMessage = "Brak statystyk dla gry \(game.displayName)."
            }
        } catch {
            if selectedGame == game {
                if stats?.game != game {
                    stats = statsByGame[game]
                }

                errorMessage = error.localizedDescription
            }
        }
        
        isLoading = false

        if selectedGame != game {
            if let cachedStats = statsByGame[selectedGame] {
                stats = cachedStats
                errorMessage = nil
            } else {
                await loadData(for: selectedGame)
            }
        }
    }
}

struct StatisticsCard<Content: View>: View {
    let tint: Color?
    @ViewBuilder let content: Content

    init(tint: Color? = nil, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        AppCard(tint: tint) {
            content
        }
    }
}

private struct StatisticSummaryTile: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .minimumScaleFactor(0.75)
                .lineLimit(2)

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

struct FrequencyGrid: View {
    let items: [LottoFrequencyItem]
    let circleColor: Color
    var highlightsTopThree = false

    private let columns = [
        GridItem(.adaptive(minimum: 58), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                VStack(spacing: 7) {
                    ZStack(alignment: .topTrailing) {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [circleColor.opacity(0.92), circleColor.opacity(0.58)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                            .overlay {
                                Circle()
                                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
                            }
                            .shadow(color: circleColor.opacity(0.22), radius: 6, x: 0, y: 4)

                        Text("\(item.number)")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)

                        if highlightsTopThree && index < 3 {
                            Text("\(index + 1)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(circleColor)
                                .frame(width: 18, height: 18)
                                .background(.white)
                                .clipShape(Circle())
                                .overlay {
                                    Circle().stroke(circleColor.opacity(0.18), lineWidth: 1)
                                }
                                .offset(x: 2, y: -2)
                        }
                    }

                    Text("\(item.numberOfOccurrences)x")
                        .font(.caption.weight(.semibold))

                    Text(percentText(for: item))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func percentText(for item: LottoFrequencyItem) -> String {
        let percent = item.percentOfOccurrences

        if percent.rounded() == percent {
            return "\(Int(percent))%"
        }

        return String(format: "%.1f%%", percent)
    }
}

#Preview {
    NavigationStack {
        StatisticsView()
    }
}
