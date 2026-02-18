//
//  BackupView.swift
//  MoneyTrackerApp
//
//  Export and import all app data for backup before reinstalling.
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct BackupView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var showImportPicker = false
    @State private var exportFileURL: URL?
    @State private var alertMessage: String?
    @State private var showAlert = false
    @State private var showImportConfirm = false
    @State private var importURL: URL?

    var body: some View {
        NavigationView {
            ZStack {
                Color.cyberBlack.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Info
                        VStack(spacing: 12) {
                            Image(systemName: "externaldrive.badge.icloud")
                                .font(.system(size: 48))
                                .foregroundColor(.neonGreen.opacity(0.8))

                            Text("Backup & Restore")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)

                            Text("Export your transactions, presets, and budgets to a JSON file. Save it to Files, iCloud, or AirDrop before reinstalling the app.")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.vertical, 24)

                        // Export
                        VStack(spacing: 16) {
                            CyberSectionHeader(title: "Export backup")
                            Text("Save a copy of all your data to share or store elsewhere.")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Button {
                                exportBackup()
                            } label: {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Export Backup")
                                }
                                .font(.headline)
                                .foregroundColor(.cyberBlack)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.neonGreen)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: .neonGreenGlow, radius: 8)
                            }
                        }
                        .padding()
                        .cyberCard()

                        // Import
                        VStack(spacing: 16) {
                            CyberSectionHeader(title: "Restore from backup")
                            Text("Replace current data with a previously exported backup file.")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Button {
                                showImportPicker = true
                            } label: {
                                HStack {
                                    Image(systemName: "square.and.arrow.down")
                                    Text("Choose Backup File")
                                }
                                .font(.headline)
                                .foregroundColor(.neonGreen)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.cyberGray)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.neonGreen.opacity(0.5), lineWidth: 1)
                                )
                            }
                        }
                        .padding()
                        .cyberCard()
                    }
                    .padding()
                }
            }
            .cyberNavTitle("Backup")
            .sheet(item: Binding(
                get: { exportFileURL.map { IdentifiableURL(url: $0) } },
                set: { exportFileURL = $0?.url }
            )) { identifiable in
                ShareSheet(items: [identifiable.url])
            }
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    if url.startAccessingSecurityScopedResource() {
                        importURL = url
                        showImportConfirm = true
                    } else {
                        alertMessage = "Could not access file"
                        showAlert = true
                    }
                case .failure:
                    alertMessage = "Could not select file"
                    showAlert = true
                }
            }
            .confirmationDialog("Restore Backup?", isPresented: $showImportConfirm) {
                Button("Restore", role: .destructive) {
                    if let url = importURL {
                        restoreBackup(from: url)
                        url.stopAccessingSecurityScopedResource()
                        importURL = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    importURL?.stopAccessingSecurityScopedResource()
                    importURL = nil
                }
            } message: {
                Text("This will replace all current transactions, presets, and budgets. This cannot be undone.")
            }
            .alert("Backup", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    private func exportBackup() {
        if let url = BackupManager.exportToFile(context: viewContext) {
            exportFileURL = url
        } else {
            alertMessage = "Export failed"
            showAlert = true
        }
    }

    private func restoreBackup(from url: URL) {
        if let error = BackupManager.importFromFile(url: url, context: viewContext) {
            alertMessage = error
            showAlert = true
            return
        }
        do {
            try viewContext.save()
            alertMessage = "Restore complete. Your data has been restored."
            showAlert = true
        } catch {
            alertMessage = "Restore failed: \(error.localizedDescription)"
            showAlert = true
        }
    }
}

private struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

// Share sheet for exporting
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
