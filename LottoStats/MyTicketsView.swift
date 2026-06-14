import SwiftUI

struct MyTicketsView: View {
    @ObservedObject var viewModel: TicketViewModel
    @State private var selectedSection: TicketScreenSection = .saved
    @State private var selectedTicket: LottoTicket?

    private enum TicketScreenSection: String, CaseIterable, Identifiable {
        case saved = "Moje kupony"
        case add = "Dodaj kupon"

        var id: String { rawValue }
    }

    private var selectedGameBinding: Binding<LottoGame> {
        Binding {
            viewModel.selectedGame
        } set: { game in
            Task {
                await viewModel.selectGame(game)
            }
        }
    }

    private var mainPickerBallStyle: TicketPickerBallStyle {
        switch viewModel.selectedGame {
        case .lotto:
            return .lotto
        case .miniLotto:
            return .miniLotto
        case .eurojackpot:
            return .euro
        }
    }

    private var activeTicketsCount: Int {
        viewModel.tickets.filter { ticket in
            if case .active = viewModel.checkResult(for: ticket).status {
                return true
            }
            return false
        }.count
    }

    private var checkedTicketsCount: Int {
        viewModel.tickets.filter { ticket in
            if case .checked = viewModel.checkResult(for: ticket).status {
                return true
            }
            return false
        }.count
    }

    private var partiallyCheckedTicketsCount: Int {
        viewModel.tickets.filter { ticket in
            if case .partiallyChecked = viewModel.checkResult(for: ticket).status {
                return true
            }
            return false
        }.count
    }

    private var waitingTicketsCount: Int {
        viewModel.tickets.filter { ticket in
            if case .waitingForResults = viewModel.checkResult(for: ticket).status {
                return true
            }
            return false
        }.count
    }

    private var totalLinesCount: Int {
        viewModel.tickets.reduce(0) { partialResult, ticket in
            partialResult + ticket.lines.count
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerView
                sectionPicker

                switch selectedSection {
                case .saved:
                    savedTicketsContent
                case .add:
                    addTicketContent
                }
            }
            .padding()
            .safeAreaPadding(.bottom, 120)
        }
        .background(AppTheme.screenBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.refreshUpcomingDrawDates()
            await viewModel.refreshTicketResults(includePrizes: true)
        }
        .alert("Usunąć kupon?", isPresented: $viewModel.showDeleteAlert) {
            Button("Usuń", role: .destructive) {
                viewModel.confirmDelete()
            }

            Button("Anuluj", role: .cancel) {
                viewModel.cancelDelete()
            }
        } message: {
            Text("Tego działania nie można cofnąć.")
        }
        .navigationDestination(item: $selectedTicket) { ticket in
            TicketDetailView(
                ticket: ticket,
                checkResult: viewModel.checkResult(for: ticket),
                winningsSummary: viewModel.winningsSummary(for: ticket),
                isLoadingWinnings: viewModel.isLoadingTicketPrizes
            )
            .task {
                await viewModel.refreshTicketPrizes(for: ticket)
            }
        }
    }

    private var headerView: some View {
        ScreenHeader(
            title: selectedSection == .saved ? "Moje kupony" : "Dodaj kupon",
            subtitle: selectedSection == .saved
                ? "Sprawdzaj wyniki i zarządzaj zapisanymi kuponami."
                : "Wybierz grę, liczby i zapisz nowy kupon.",
            icon: selectedSection == .saved ? "ticket.fill" : "plus.circle.fill",
            tint: selectedSection == .saved ? AppTheme.accent : viewModel.selectedGame.visualColor
        )
        .animation(.easeInOut(duration: 0.22), value: selectedSection)
    }

    private var sectionPicker: some View {
        HStack(spacing: 7) {
            ForEach(TicketScreenSection.allCases) { section in
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        selectedSection = section
                    }
                } label: {
                    Text(section.rawValue)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .foregroundStyle(selectedSection == section ? Color.white : Color.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background {
                            if selectedSection == section {
                                LinearGradient(
                                    colors: [activeSectionTint, activeSectionTint.opacity(0.68)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            } else {
                                Color(.tertiarySystemFill)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(
                                    selectedSection == section
                                        ? Color.white.opacity(0.18)
                                        : Color(.separator).opacity(0.12),
                                    lineWidth: 1
                                )
                        }
                        .shadow(
                            color: selectedSection == section ? activeSectionTint.opacity(0.24) : .clear,
                            radius: 6,
                            x: 0,
                            y: 3
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(section.rawValue)
            }
        }
        .padding(5)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var activeSectionTint: Color {
        selectedSection == .saved ? AppTheme.accent : viewModel.selectedGame.visualColor
    }

    @ViewBuilder
    private var savedTicketsContent: some View {
        compactSummaryCard

        if let errorMessage = viewModel.ticketResultsErrorMessage {
            MessageBanner(
                icon: "exclamationmark.triangle.fill",
                text: errorMessage,
                tint: .orange
            )
        }

        filterBar
        savedTicketsList
    }

    private var compactSummaryCard: some View {
        AppCard(tint: AppTheme.accent) {
            VStack(alignment: .leading, spacing: 14) {
                CardHeader(
                    title: "Podsumowanie kuponów",
                    subtitle: "\(totalLinesCount) zestawów w \(viewModel.tickets.count) kuponach",
                    icon: "ticket.fill",
                    tint: AppTheme.accent
                ) {
                    IconCircleButton(
                        systemImage: "arrow.clockwise",
                        tint: AppTheme.accent,
                        isLoading: viewModel.isLoadingTicketResults
                    ) {
                        Task {
                            await viewModel.refreshTicketResults(forceRefresh: true, includePrizes: true)
                        }
                    }
                    .accessibilityLabel("Odśwież wyniki kuponów")
                }

                HStack(spacing: 10) {
                    CompactMetric(
                        value: "\(viewModel.tickets.count)",
                        label: "Wszystkie",
                        tint: AppTheme.accent
                    )

                    CompactMetric(
                        value: "\(activeTicketsCount)",
                        label: "Aktywne",
                        tint: .green
                    )

                    CompactMetric(
                        value: "\(checkedTicketsCount)",
                        label: "Sprawdzone",
                        tint: .purple
                    )
                }

                if partiallyCheckedTicketsCount > 0 || waitingTicketsCount > 0 {
                    Divider()

                    HStack(spacing: 18) {
                        if partiallyCheckedTicketsCount > 0 {
                            Label("\(partiallyCheckedTicketsCount) częściowo", systemImage: "circle.lefthalf.filled")
                        }

                        if waitingTicketsCount > 0 {
                            Label("\(waitingTicketsCount) oczekuje", systemImage: "clock")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var filterBar: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(TicketStatusFilter.allCases) { filter in
                    Button {
                        viewModel.selectedStatusFilter = filter
                    } label: {
                        if viewModel.selectedStatusFilter == filter {
                            Label(filter.displayName, systemImage: "checkmark")
                        } else {
                            Text(filter.displayName)
                        }
                    }
                }
            } label: {
                FilterButton(
                    icon: "line.3.horizontal.decrease.circle",
                    title: viewModel.selectedStatusFilter.displayName
                )
            }

            Menu {
                ForEach(TicketGameFilter.allCases) { filter in
                    Button {
                        viewModel.selectedGameFilter = filter
                    } label: {
                        if viewModel.selectedGameFilter == filter {
                            Label(filter.displayName, systemImage: "checkmark")
                        } else {
                            Text(filter.displayName)
                        }
                    }
                }
            } label: {
                FilterButton(
                    icon: "gamecontroller",
                    title: viewModel.selectedGameFilter.displayName
                )
            }

            Spacer()

            Text("\(viewModel.filteredTicketsCount)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var savedTicketsList: some View {
        if viewModel.tickets.isEmpty {
            EmptyTicketsCard {
                selectedSection = .add
            }
        } else if viewModel.filteredTickets.isEmpty {
            EmptyStateCard(
                title: "Brak pasujących kuponów",
                message: "Zmień filtr statusu albo gry, aby zobaczyć inne kupony.",
                icon: "line.3.horizontal.decrease.circle",
                tint: AppTheme.accent
            )
        } else {
            VStack(spacing: 12) {
                ForEach(viewModel.filteredTickets) { ticket in
                    CompactTicketRow(
                        ticket: ticket,
                        checkResult: viewModel.checkResult(for: ticket),
                        winningsSummary: viewModel.winningsSummary(for: ticket),
                        isLoadingWinnings: viewModel.isLoadingTicketPrizes,
                        onOpen: {
                            selectedTicket = ticket
                        },
                        onDelete: {
                            viewModel.requestDelete(ticket)
                        }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var addTicketContent: some View {
        drawSetupCard
        numbersCard
        messagesSection
        draftSection
        saveTicketButton
    }

    private var drawSetupCard: some View {
        AppCard(tint: viewModel.selectedGame.visualColor) {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(
                    title: "Losowanie",
                    subtitle: "Wybierz grę i liczbę kolejnych losowań",
                    icon: "calendar.badge.plus",
                    tint: viewModel.selectedGame.visualColor
                )

                Picker("Gra", selection: selectedGameBinding) {
                    ForEach(viewModel.availableGamesForTickets) { game in
                        Text(game.displayName)
                            .tag(game)
                    }
                }
                .pickerStyle(.segmented)
                .tint(viewModel.selectedGame.visualColor)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Liczba losowań")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Spacer()

                        if viewModel.isLoadingDrawDates {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Button {
                                Task {
                                    await viewModel.refreshUpcomingDrawDates(forceRefresh: true)
                                }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                            .accessibilityLabel("Odśwież daty losowań")
                        }
                    }

                    Picker("Liczba losowań", selection: $viewModel.selectedDrawCount) {
                        ForEach(viewModel.drawCountOptions, id: \.self) { count in
                            Text("\(count)").tag(count)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(viewModel.selectedGame.visualColor)
                }

                if let drawDatesErrorMessage = viewModel.drawDatesErrorMessage {
                    Text(drawDatesErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else if viewModel.selectedDrawDates.isEmpty {
                    Text("Brak dostępnych terminów losowań.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 8) {
                        ForEach(Array(viewModel.selectedDrawDates.enumerated()), id: \.offset) { index, date in
                            HStack {
                                Text(index == 0 ? "Najbliższe" : "Losowanie \(index + 1)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Text(AppFormatters.polishLongDate.string(from: date))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if viewModel.currentRules.supportsPlus {
                    Divider()

                    Toggle(isOn: $viewModel.includesPlus) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Lotto Plus")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Text("Te same zestawy wezmą udział także w losowaniu Plus.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var numbersCard: some View {
        AppCard(tint: viewModel.selectedGame.visualColor) {
            VStack(alignment: .leading, spacing: 18) {
                CardHeader(
                    title: "Wybierz liczby",
                    subtitle: viewModel.mainSelectionProgressText,
                    icon: "circle.grid.3x3.fill",
                    tint: viewModel.selectedGame.visualColor
                ) {
                    GameBadge(game: viewModel.selectedGame)
                }

                HStack(spacing: 10) {
                    Button {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.76)) {
                            viewModel.generateRandomTicket()
                        }
                    } label: {
                        Label("Wylosuj liczby", systemImage: "dice.fill")
                    }
                    .buttonStyle(SecondaryActionButtonStyle(tint: viewModel.selectedGame.visualColor))

                    Button(role: .destructive) {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            viewModel.clearCurrentInputs()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.bold))
                            .frame(width: 44, height: 44)
                            .background(Color.red.opacity(0.11))
                            .foregroundStyle(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Wyczyść wybrane liczby")
                }

                TicketNumberSelectionGrid(
                    numbers: Array(viewModel.currentRules.mainNumberRange),
                    selectedNumbers: viewModel.selectedMainNumbers,
                    ballStyle: mainPickerBallStyle
                ) { number in
                    viewModel.toggleMainNumber(number)
                }

                if viewModel.currentRules.extraNumbersCount > 0,
                   let extraRange = viewModel.currentRules.extraNumberRange {
                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Euroliczby")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Text(viewModel.extraSelectionProgressText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        TicketNumberSelectionGrid(
                            numbers: Array(extraRange),
                            selectedNumbers: viewModel.selectedExtraNumbers,
                            ballStyle: .euro
                        ) { number in
                            viewModel.toggleExtraNumber(number)
                        }
                    }
                }

                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                        viewModel.addCurrentLineToDraft()
                    }
                } label: {
                    Label("Dodaj zestaw", systemImage: "plus.circle.fill")
                }
                .buttonStyle(
                    PrimaryActionButtonStyle(
                        tint: viewModel.selectedGame.visualColor,
                        isEnabled: viewModel.canAddCurrentLine
                    )
                )
                .disabled(!viewModel.canAddCurrentLine)
            }
        }
    }

    @ViewBuilder
    private var messagesSection: some View {
        if let errorMessage = viewModel.errorMessage {
            MessageBanner(
                icon: "xmark.circle.fill",
                text: errorMessage,
                tint: .red
            )
        }

        if let successMessage = viewModel.successMessage {
            MessageBanner(
                icon: "checkmark.circle.fill",
                text: successMessage,
                tint: .green
            )
        }
    }

    private var draftSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(
                    title: "Zestawy na kuponie",
                    subtitle: viewModel.draftLinesCountText,
                    icon: "list.bullet.rectangle.fill",
                    tint: viewModel.selectedGame.visualColor
                )

                if !viewModel.draftLines.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.clearDraftLines()
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.red)
                            .frame(width: 34, height: 34)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Wyczyść wszystkie zestawy")
                }
            }

            if viewModel.draftLines.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(viewModel.selectedGame.visualColor)

                    Text("Zaznacz liczby i dodaj pierwszy zestaw.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(viewModel.selectedGame.visualColor.opacity(0.075))
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            } else {
                ForEach(Array(viewModel.draftLines.enumerated()), id: \.element.id) { index, line in
                    DraftLineRow(
                        index: index,
                        line: line,
                        mainStyle: viewModel.selectedGame.ballStyle
                    ) {
                        viewModel.removeDraftLine(line)
                    }
                }
            }
        }
    }

    private var saveTicketButton: some View {
        Button {
            viewModel.saveTicket()
        } label: {
            Label("Zapisz kupon", systemImage: "ticket.fill")
        }
        .buttonStyle(
            PrimaryActionButtonStyle(
                tint: viewModel.selectedGame.visualColor,
                isEnabled: viewModel.canSaveTicket
            )
        )
        .disabled(!viewModel.canSaveTicket)
    }
}

private struct CompactMetric: View {
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(tint)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            LinearGradient(
                colors: [tint.opacity(0.13), tint.opacity(0.055)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(tint.opacity(0.13), lineWidth: 1)
        }
    }
}

private struct FilterButton: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.caption2)
        }
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.thinMaterial)
        .clipShape(Capsule())
        .overlay {
            Capsule().stroke(Color(.separator).opacity(0.22), lineWidth: 1)
        }
    }
}

private struct MessageBanner: View {
    let icon: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)

            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(tint.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct EmptyTicketsCard: View {
    let onAdd: () -> Void

    var body: some View {
        EmptyStateCard(
            title: "Nie masz jeszcze kuponów",
            message: "Dodaj pierwszy kupon, a LottoStats automatycznie sprawdzi jego wyniki po losowaniu.",
            icon: "ticket.fill",
            tint: AppTheme.accent,
            action: onAdd
        ) {
            Label("Dodaj pierwszy kupon", systemImage: "plus.circle.fill")
        }
    }
}

enum TicketPickerBallStyle {
    case lotto
    case miniLotto
    case euro
}

struct TicketNumberSelectionGrid: View {
    let numbers: [Int]
    let selectedNumbers: [Int]
    let ballStyle: TicketPickerBallStyle
    let onTap: (Int) -> Void

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 8),
        count: 7
    )

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(numbers, id: \.self) { number in
                Button {
                    onTap(number)
                } label: {
                    SelectableLottoBall(
                        number: number,
                        isSelected: selectedNumbers.contains(number),
                        style: ballStyle
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct SelectableLottoBall: View {
    let number: Int
    let isSelected: Bool
    let style: TicketPickerBallStyle

    var body: some View {
        ZStack {
            Circle()
                .fill(ballBackground)
                .frame(width: 42, height: 42)
                .overlay(
                    Circle()
                        .stroke(ballBorder, lineWidth: isSelected ? 0 : 1)
                )
                .shadow(
                    color: isSelected ? .black.opacity(0.16) : .black.opacity(0.06),
                    radius: isSelected ? 5 : 2,
                    x: 0,
                    y: isSelected ? 2 : 1
                )

            Text("\(number)")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(numberColor)
        }
        .scaleEffect(isSelected ? 1.04 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    private var ballBackground: LinearGradient {
        if isSelected {
            switch style {
            case .lotto:
                return LinearGradient(
                    colors: [
                        Color(red: 0.18, green: 0.61, blue: 1.0),
                        Color(red: 0.08, green: 0.36, blue: 0.82)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .miniLotto:
                return LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.72, blue: 0.22),
                        Color(red: 0.94, green: 0.42, blue: 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .euro:
                return LinearGradient(
                    colors: [
                        Color(red: 0.46, green: 0.35, blue: 1.0),
                        Color(red: 0.24, green: 0.10, blue: 0.90)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }

        return LinearGradient(
            colors: [
                Color(.tertiarySystemBackground),
                Color(.secondarySystemBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var ballBorder: Color {
        isSelected ? .clear : Color(.systemGray5)
    }

    private var numberColor: Color {
        if isSelected {
            switch style {
            case .lotto, .miniLotto, .euro:
                return .white
            }
        }

        return Color(.label)
    }
}

struct DraftLineRow: View {
    let index: Int
    let line: TicketLine
    let mainStyle: NumberBallStyle
    let onDelete: () -> Void

    var body: some View {
        AppCard(tint: AppTheme.accent) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Zestaw \(index + 1)")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Spacer()

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                }

                BallRow(numbers: line.numbers, style: mainStyle)

                if !line.extraNumbers.isEmpty {
                    BallRow(numbers: line.extraNumbers, style: .plus)
                }
            }
        }
    }
}

private struct BallRow: View {
    let numbers: [Int]
    let style: NumberBallStyle

    var body: some View {
        HStack(spacing: 7) {
            ForEach(numbers, id: \.self) { number in
                NumberBall(number: number, style: style, size: 32)
            }
        }
    }
}

private struct CompactTicketRow: View {
    let ticket: LottoTicket
    let checkResult: TicketCheckResult
    let winningsSummary: TicketWinningsSummary
    let isLoadingWinnings: Bool
    let onOpen: () -> Void
    let onDelete: () -> Void

    private var dateRangeText: String {
        let sortedDates = ticket.drawDates.sorted()

        guard let firstDate = sortedDates.first,
              let lastDate = sortedDates.last else {
            return "Brak dat losowań"
        }

        if Calendar.current.isDate(firstDate, inSameDayAs: lastDate) {
            return AppFormatters.polishLongDate.string(from: firstDate)
        }

        return "\(AppFormatters.polishShortDate.string(from: firstDate)) – \(AppFormatters.polishShortDate.string(from: lastDate))"
    }

    private var firstLine: TicketLine? {
        ticket.lines.first
    }

    private var bestMainHit: Int {
        checkResult.checkedDraws
            .flatMap { $0.lineResults }
            .map { $0.lottoMatchedNumbers.count }
            .max() ?? 0
    }

    private var resultSummary: String {
        switch checkResult.status {
        case .active:
            return "Oczekuje na losowanie"
        case .waitingForResults:
            return "Oczekuje na publikację wyników"
        case .partiallyChecked:
            return "Sprawdzono \(checkResult.checkedDrawsCount)/\(checkResult.totalDrawsCount) losowań"
        case .checked:
            if bestMainHit == 0 {
                return "Brak trafień"
            }
            return "Najlepszy wynik: \(hitText(bestMainHit))"
        }
    }

    private var shouldShowWinnings: Bool {
        !checkResult.checkedDraws.isEmpty
    }

    private var winningsText: String {
        if winningsSummary.isComplete {
            if winningsSummary.hasAnyWin {
                let prefix = checkResult.status == .checked ? "Wygrana" : "Dotychczasowa wygrana"
                return "\(prefix): \(AppFormatters.currency(winningsSummary.totalAmount))"
            }

            return checkResult.status == .checked
                ? "Brak wygranej pieniężnej"
                : "Dotychczas brak wygranej pieniężnej"
        }

        if isLoadingWinnings {
            return "Obliczanie wygranej..."
        }

        return "Kwota wygranej niedostępna"
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Button(action: onOpen) {
                AppCard(tint: ticket.game.visualColor) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            HStack(spacing: 10) {
                                Image(systemName: ticket.game.symbolName)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 36, height: 36)
                                    .background(ticket.game.visualGradient)
                                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(ticket.gameName)
                                        .font(.headline)

                                    Text(dateRangeText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 6) {
                                StatusBadge(status: checkResult.status)

                                if winningsSummary.hasAnyWin {
                                    CelebrationBadge(
                                        text: AppFormatters.currency(
                                            winningsSummary.totalAmount,
                                            fractionDigits: 2
                                        ),
                                        tint: .green
                                    )
                                } else if checkResult.status == .checked && bestMainHit >= 3 {
                                    CelebrationBadge(
                                        text: hitText(bestMainHit),
                                        tint: .green
                                    )
                                }
                            }
                        }

                        HStack(spacing: 8) {
                            Label("\(ticket.lines.count) zest.", systemImage: "list.number")
                            Label("\(ticket.drawDates.count) los.", systemImage: "calendar")

                            if ticket.includesPlus {
                                Label("Plus", systemImage: "plus.circle.fill")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        if let firstLine {
                            VStack(alignment: .leading, spacing: 8) {
                                BallRow(numbers: firstLine.numbers, style: ticket.game.ballStyle)

                                if !firstLine.extraNumbers.isEmpty {
                                    BallRow(numbers: firstLine.extraNumbers, style: .plus)
                                }

                                if ticket.lines.count > 1 {
                                    Text("+ \(ticket.lines.count - 1) kolejnych zestawów")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Divider()

                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(resultSummary)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)

                                if shouldShowWinnings {
                                    Label(winningsText, systemImage: "banknote.fill")
                                        .font(.caption)
                                        .fontWeight(winningsSummary.hasAnyWin ? .semibold : .regular)
                                        .foregroundStyle(winningsSummary.hasAnyWin ? Color.green : Color.secondary)
                                }

                                Text("Dodano \(AppFormatters.polishDateTime.string(from: ticket.createdAt))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 0)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .contentShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
            .accessibilityHint("Otwiera szczegóły kuponu")

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .padding(9)
                    .background(Color.red.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 18)
            .padding(.bottom, 18)
            .accessibilityLabel("Usuń kupon")
        }
    }

    private func hitText(_ count: Int) -> String {
        switch count {
        case 1:
            return "1 trafienie"
        case 2...4:
            return "\(count) trafienia"
        default:
            return "\(count) trafień"
        }
    }
}

private struct StatusBadge: View {
    let status: TicketStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(statusColor)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(backgroundColor)
            .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch status {
        case .checked:
            return Color.green.opacity(0.18)
        case .partiallyChecked:
            return Color.orange.opacity(0.18)
        case .active:
            return AppTheme.accent.opacity(0.18)
        case .waitingForResults:
            return Color.orange.opacity(0.18)
        }
    }

    private var statusColor: Color {
        switch status {
        case .checked:
            return .green
        case .partiallyChecked, .waitingForResults:
            return .orange
        case .active:
            return AppTheme.accent
        }
    }
}

#Preview {
    NavigationStack {
        MyTicketsView(viewModel: TicketViewModel())
    }
}
