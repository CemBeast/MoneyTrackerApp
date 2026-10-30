//
//  RecurringTransactionsView.swift
//  MoneyTrackerApp
//
//  Lists recurring schedules. Schedules are rules, not logs; the logs they generate live in the Transaction Log.
//

import SwiftUI
import CoreData

struct RecurringTransactionsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var currencyViewModel: CurrencyViewModel

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CDRecurringSchedule.createdAt, ascending: false)]
    )
    private var schedules: FetchedResults<CDRecurringSchedule>

    @State private var scheduleToRemove: CDRecurringSchedule?

    var body: some View {
        ZStack {
            Color.cyberBlack.ignoresSafeArea()

            if schedules.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "repeat.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.neonGreen.opacity(0.3))

                    Text("No recurring transactions")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.5))

                    Text("Tap + to add one, or open a log and tap Make Recurring")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.3))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 60)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(schedules) { schedule in
                            NavigationLink(destination: RecurringScheduleEditView(schedule: schedule)) {
                                CyberScheduleRow(schedule: schedule, currencyViewModel: currencyViewModel)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    scheduleToRemove = schedule
                                } label: {
                                    Label("Remove Recurring", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .cyberNavTitle("Recurring")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: RecurringScheduleEditView()) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.neonGreen)
                }
            }
        }
        .confirmationDialog(
            "Remove Recurring?",
            isPresented: Binding(
                get: { scheduleToRemove != nil },
                set: { if !$0 { scheduleToRemove = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove Recurring", role: .destructive) {
                if let schedule = scheduleToRemove {
                    RecurringEngine.removeSchedule(schedule, in: viewContext)
                    PersistenceController.shared.save(viewContext)
                }
                scheduleToRemove = nil
            }
            Button("Cancel", role: .cancel) {
                scheduleToRemove = nil
            }
        } message: {
            Text("No new transactions will be generated. Past logged transactions are kept.")
        }
    }
}

struct CyberScheduleRow: View {
    @ObservedObject var schedule: CDRecurringSchedule
    @ObservedObject var currencyViewModel: CurrencyViewModel

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(categoryColor.opacity(0.5), lineWidth: 1)
                    )

                Image(systemName: schedule.category.icon)
                    .font(.system(size: 18))
                    .foregroundColor(categoryColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(schedule.merchant ?? "No merchant")
                        .font(.headline)
                        .foregroundColor(.white)

                    Spacer()

                    Text(currencyViewModel.format(schedule: schedule))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.neonGreen)
                }

                HStack(spacing: 8) {
                    CyberTag(text: schedule.category.rawValue, color: categoryColor)
                    CyberTag(text: schedule.interval.rawValue.capitalized, color: .neonGreen)

                    Spacer()

                    Text("Since \(schedule.startDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.cyberDarkGray)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(categoryColor.opacity(0.2), lineWidth: 1)
        )
    }

    private var categoryColor: Color {
        schedule.category.color
    }
}
