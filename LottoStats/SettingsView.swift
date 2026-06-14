import SwiftUI

struct SettingsView: View {
    @ObservedObject var ticketViewModel: TicketViewModel

    @State private var showClearTicketsAlert = false
    @State private var showClearCheckedTicketsAlert = false
    @State private var showClearCacheAlert = false
    @State private var lastSyncDate: Date?
    @State private var cacheSizeBytes: Int64 = 0

    private let repository = LottoRepository.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerView
                dataSourceSection
                cacheSection
                ticketsSection
                aboutSection
            }
            .padding()
            .safeAreaPadding(.bottom, 110)
        }
        .background(AppTheme.screenBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            refreshCacheInfo()
        }
        .alert("Usunąć wszystkie kupony?", isPresented: $showClearTicketsAlert) {
            Button("Usuń", role: .destructive) {
                ticketViewModel.clearAllTickets()
            }

            Button("Anuluj", role: .cancel) {}
        } message: {
            Text("Tego działania nie można cofnąć.")
        }
        .alert("Usunąć sprawdzone kupony?", isPresented: $showClearCheckedTicketsAlert) {
            Button("Usuń sprawdzone", role: .destructive) {
                ticketViewModel.clearCheckedTickets()
            }

            Button("Anuluj", role: .cancel) {}
        } message: {
            Text("Usunięte zostaną tylko kupony, dla których pobrano wyniki wszystkich przypisanych losowań. Aktywne i oczekujące kupony pozostaną zapisane.")
        }
        .alert("Wyczyścić pamięć podręczną?", isPresented: $showClearCacheAlert) {
            Button("Wyczyść", role: .destructive) {
                ticketViewModel.clearCachedAPIData()
                refreshCacheInfo()
            }

            Button("Anuluj", role: .cancel) {}
        } message: {
            Text("Zapisane kupony pozostaną bez zmian. Wyniki, statystyki i kwoty wygranych zostaną pobrane ponownie przy kolejnym odświeżeniu.")
        }
    }

    private var headerView: some View {
        ScreenHeader(
            title: "Ustawienia",
            subtitle: "Zarządzaj danymi aplikacji i zapisanymi kuponami.",
            icon: "gearshape.fill",
            tint: Color.indigo
        )
    }

    private var dataSourceSection: some View {
        AppCard(tint: .green) {
            VStack(alignment: .leading, spacing: 14) {
                CardHeader(
                    title: "Źródło danych",
                    subtitle: "Status połączenia z serwisem LOTTO",
                    icon: "network",
                    tint: .green
                ) {
                    Image(systemName: LottoAPIConfiguration.shouldUseRealAPI ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(LottoAPIConfiguration.shouldUseRealAPI ? Color.green : Color.orange)
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(repository.dataSourceName)
                            .font(.title3)
                            .fontWeight(.bold)

                        Label(
                            LottoAPIConfiguration.shouldUseRealAPI ? "Połączenie aktywne" : "Tryb danych testowych",
                            systemImage: LottoAPIConfiguration.shouldUseRealAPI ? "bolt.horizontal.circle.fill" : "wrench.and.screwdriver.fill"
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(13)
                .background(Color.green.opacity(0.075))
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
        }
    }

    private var cacheSection: some View {
        AppCard(tint: .cyan) {
            VStack(alignment: .leading, spacing: 14) {
                CardHeader(
                    title: "Synchronizacja i cache",
                    subtitle: "Dane API zapisane lokalnie dla szybszego działania",
                    icon: "externaldrive.fill.badge.checkmark",
                    tint: .cyan
                )

                VStack(spacing: 10) {
                    settingsInfoRow(
                        icon: "clock.arrow.circlepath",
                        title: "Ostatnia synchronizacja",
                        value: lastSyncText,
                        tint: .cyan
                    )

                    settingsInfoRow(
                        icon: "internaldrive.fill",
                        title: "Rozmiar pamięci podręcznej",
                        value: cacheSizeText,
                        tint: .cyan
                    )
                }

                Button {
                    showClearCacheAlert = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "trash.slash.fill")

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Wyczyść pamięć podręczną")
                                .fontWeight(.semibold)

                            Text("Kupony nie zostaną usunięte")
                                .font(.caption2)
                                .opacity(0.78)
                        }

                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.cyan.opacity(0.1))
                    .foregroundStyle(.cyan)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(Color.cyan.opacity(0.16), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .disabled(cacheSizeBytes == 0)
                .opacity(cacheSizeBytes == 0 ? 0.48 : 1)
            }
        }
    }

    private var ticketsSection: some View {
        AppCard(tint: AppTheme.accent) {
            VStack(alignment: .leading, spacing: 16) {
                CardHeader(
                    title: "Zapisane kupony",
                    subtitle: "Dane są przechowywane lokalnie na urządzeniu",
                    icon: "ticket.fill",
                    tint: AppTheme.accent
                ) {
                    Text("\(ticketViewModel.tickets.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.accent.opacity(0.11))
                        .clipShape(Capsule())
                }

                HStack(spacing: 12) {
                    ticketMetric(
                        value: ticketViewModel.tickets.count,
                        title: "Wszystkie",
                        icon: "ticket.fill",
                        tint: AppTheme.accent
                    )

                    ticketMetric(
                        value: ticketViewModel.checkedTicketsCount,
                        title: "Sprawdzone",
                        icon: "checkmark.circle.fill",
                        tint: .orange
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        showClearCheckedTicketsAlert = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "trash.circle.fill")

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Usuń sprawdzone kupony")
                                    .fontWeight(.semibold)

                                Text("Tylko zakończone i w pełni sprawdzone")
                                    .font(.caption2)
                                    .opacity(0.78)
                            }

                            Spacer()

                            Text("\(ticketViewModel.checkedTicketsCount)")
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(Color.orange.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.orange.opacity(0.11))
                        .foregroundStyle(.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .stroke(Color.orange.opacity(0.16), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(ticketViewModel.checkedTicketsCount == 0)
                    .opacity(ticketViewModel.checkedTicketsCount == 0 ? 0.48 : 1)

                    Button(role: .destructive) {
                        showClearTicketsAlert = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "trash")
                            Text("Usuń wszystkie kupony")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .background(Color.red.opacity(0.11))
                        .foregroundStyle(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .stroke(Color.red.opacity(0.15), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(ticketViewModel.tickets.isEmpty)
                    .opacity(ticketViewModel.tickets.isEmpty ? 0.48 : 1)
                }
            }
        }
    }

    private func ticketMetric(
        value: Int,
        title: String,
        icon: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("\(value)")
                    .font(.title3.weight(.bold))

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color(.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private func settingsInfoRow(
        icon: String,
        title: String,
        value: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.subheadline.weight(.semibold))
            }

            Spacer()
        }
        .padding(12)
        .background(Color(.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private var aboutSection: some View {
        AppCard(tint: Color.indigo) {
            VStack(alignment: .leading, spacing: 12) {
                CardHeader(
                    title: "O aplikacji",
                    subtitle: AppMetadata.versionText,
                    icon: "info.circle.fill",
                    tint: Color.indigo
                ) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.indigo)
                }

                HStack(spacing: 14) {
                    EmptyStateArtwork(
                        icon: "sparkles",
                        tint: Color.indigo,
                        size: 72
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("LottoStats")
                            .font(.title3)
                            .fontWeight(.bold)

                        Text("Wyniki, kupony i statystyki")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Aplikacja do sprawdzania wyników losowań, analizowania statystyk liczb oraz zapisywania własnych kuponów Lotto.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Aplikacja obsługuje Lotto, Mini Lotto i Eurojackpot, lokalne kupony, Lotto Plus, kupony wielolosowaniowe oraz dane z API LOTTO.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var lastSyncText: String {
        guard let lastSyncDate else {
            return "Brak zapisanych danych"
        }

        return AppFormatters.polishDateTime.string(from: lastSyncDate)
    }

    private var cacheSizeText: String {
        guard cacheSizeBytes > 0 else {
            return "0 KB"
        }

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: cacheSizeBytes)
    }

    private func refreshCacheInfo() {
        lastSyncDate = LottoAPICache.shared.latestModificationDate
        cacheSizeBytes = LottoAPICache.shared.totalSizeBytes
    }
}

#Preview {
    NavigationStack {
        SettingsView(ticketViewModel: TicketViewModel())
    }
}
