import SwiftUI
import SwiftData
import CoreLocation

enum LocationSourceMode: String, CaseIterable, Identifiable {
    case currentLocation = "Device Location"
    case customAddress = "Custom Address"

    var id: String { rawValue }
}

struct ReportIncidentSheet: View {
    let initialCoordinate: CLLocationCoordinate2D?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var category: IncidentCategory = .stalking
    @State private var severity: IncidentSeverity = .medium
    @State private var details: String = ""

    // Voice memo state
    @State private var voiceMemoService = VoiceMemoService.shared
    @State private var recordedAudioFileName: String? = nil
    @State private var recordedAudioDuration: TimeInterval = 0
    @State private var didSubmitReport: Bool = false

    // Location selection state
    @State private var locationMode: LocationSourceMode = .currentLocation
    @State private var addressInput: String = ""
    @State private var isGeocoding: Bool = false
    @State private var geocodedCoordinate: CLLocationCoordinate2D? = nil
    @State private var geocodedAddressSummary: String? = nil
    @State private var geocodeErrorMessage: String? = nil
    @State private var currentAddressSummary: String? = nil

    private var activeCoordinate: CLLocationCoordinate2D? {
        switch locationMode {
        case .currentLocation:
            return initialCoordinate ?? CLLocationCoordinate2D(latitude: 59.3326, longitude: 18.0649)
        case .customAddress:
            return geocodedCoordinate
        }
    }

    private var canSubmit: Bool {
        let hasTitleOrVoice = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || recordedAudioFileName != nil
        let hasLocation = activeCoordinate != nil
        return hasTitleOrVoice && hasLocation && !isGeocoding && !voiceMemoService.isRecording
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Incident Information") {
                    TextField("Brief Summary (e.g. Followed near T-Centralen)", text: $title)

                    Picker("Category", selection: $category) {
                        ForEach(IncidentCategory.allCases) { item in
                            Label(LocalizedStringKey(item.rawValue), systemImage: item.systemImage)
                                .tag(item)
                        }
                    }

                    Picker("Threat Level", selection: $severity) {
                        ForEach(IncidentSeverity.allCases) { item in
                            Text(LocalizedStringKey(item.rawValue)).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Details & Advice for Others") {
                    TextField("Describe what happened, descriptions of individuals, or safer detours...", text: $details, axis: .vertical)
                        .lineLimit(3...6)

                    VoiceMemoRecorderInputView(
                        isRecording: voiceMemoService.isRecording,
                        isPlaying: voiceMemoService.isPlaying,
                        hasRecordedMemo: recordedAudioFileName != nil,
                        durationText: VoiceMemoService.formatDuration(
                            voiceMemoService.isRecording ? voiceMemoService.recordingDuration : recordedAudioDuration
                        ),
                        audioLevel: voiceMemoService.audioLevel,
                        errorMessage: voiceMemoService.errorMessage,
                        onToggleRecord: {
                            handleToggleRecording()
                        },
                        onTogglePreviewPlay: {
                            if let fileName = recordedAudioFileName {
                                voiceMemoService.togglePlayback(for: fileName)
                            }
                        },
                        onDeleteMemo: {
                            voiceMemoService.deleteVoiceMemo(fileName: recordedAudioFileName)
                            recordedAudioFileName = nil
                            recordedAudioDuration = 0
                        }
                    )
                }

                Section("Incident Location") {
                    Picker("Location Source", selection: $locationMode) {
                        ForEach(LocationSourceMode.allCases) { mode in
                            Text(LocalizedStringKey(mode.rawValue)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if locationMode == .currentLocation {
                        CurrentLocationDisplayView(
                            coordinate: initialCoordinate,
                            addressSummary: currentAddressSummary
                        )
                    } else {
                        CustomAddressInputView(
                            addressInput: $addressInput,
                            isGeocoding: isGeocoding,
                            errorMessage: geocodeErrorMessage,
                            resolvedAddress: geocodedAddressSummary,
                            resolvedCoordinate: geocodedCoordinate,
                            onSearch: {
                                Task { await geocodeAddress() }
                            }
                        )
                    }
                }
            }
            .navigationTitle("Report Safety Alert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        cleanupUnsavedVoiceMemo()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit Alert") {
                        submitReport()
                    }
                    .fontWeight(.bold)
                    .disabled(!canSubmit)
                }
            }
            .task {
                if let initialCoordinate {
                    await reverseGeocodeCurrentLocation(initialCoordinate)
                }
            }
            .onDisappear {
                if !didSubmitReport {
                    cleanupUnsavedVoiceMemo()
                }
            }
        }
    }

    // MARK: - Actions & Geocoding
    private func geocodeAddress() async {
        let query = addressInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        isGeocoding = true
        geocodeErrorMessage = nil

        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.geocodeAddressString(query)
            if let first = placemarks.first, let loc = first.location {
                geocodedCoordinate = loc.coordinate
                
                let street = [first.subThoroughfare, first.thoroughfare].compactMap { $0 }.joined(separator: " ")
                let city = first.locality ?? ""
                let state = first.administrativeArea ?? ""
                let summary = [street, city, state].filter { !$0.isEmpty }.joined(separator: ", ")

                geocodedAddressSummary = summary.isEmpty ? (first.name ?? query) : summary
            } else {
                geocodeErrorMessage = "No location found for this address."
                geocodedCoordinate = nil
                geocodedAddressSummary = nil
            }
        } catch {
            geocodeErrorMessage = "Could not find address. Check spelling or try again."
            geocodedCoordinate = nil
            geocodedAddressSummary = nil
        }

        isGeocoding = false
    }

    private func reverseGeocodeCurrentLocation(_ coord: CLLocationCoordinate2D) async {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        if let placemarks = try? await geocoder.reverseGeocodeLocation(location),
           let first = placemarks.first {
            let street = [first.subThoroughfare, first.thoroughfare].compactMap { $0 }.joined(separator: " ")
            let city = first.locality ?? ""
            let summary = [street, city].filter { !$0.isEmpty }.joined(separator: ", ")
            currentAddressSummary = summary.isEmpty ? first.name : summary
        }
    }

    private func handleToggleRecording() {
        if voiceMemoService.isRecording {
            let result = voiceMemoService.stopRecording()
            recordedAudioFileName = result.fileName
            recordedAudioDuration = max(1, result.duration)
        } else {
            Task {
                if let oldFile = recordedAudioFileName {
                    voiceMemoService.deleteVoiceMemo(fileName: oldFile)
                }
                let fileName = await voiceMemoService.startRecording()
                recordedAudioFileName = fileName
            }
        }
    }

    private func cleanupUnsavedVoiceMemo() {
        voiceMemoService.stopPlayback()
        if voiceMemoService.isRecording {
            _ = voiceMemoService.stopRecording()
        }
        if let fileName = recordedAudioFileName {
            voiceMemoService.deleteVoiceMemo(fileName: fileName)
            recordedAudioFileName = nil
        }
    }

    private func submitReport() {
        guard let coordinate = activeCoordinate else { return }

        voiceMemoService.stopPlayback()
        if voiceMemoService.isRecording {
            let result = voiceMemoService.stopRecording()
            recordedAudioFileName = result.fileName
            recordedAudioDuration = max(1, result.duration)
        }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = trimmedTitle.isEmpty ? "Voice Alert — \(category.rawValue)" : trimmedTitle

        let newIncident = Incident(
            title: finalTitle,
            details: details.trimmingCharacters(in: .whitespacesAndNewlines),
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            category: category,
            severity: severity,
            reportedBy: "Anonymous",
            audioFileName: recordedAudioFileName,
            audioDurationSeconds: recordedAudioFileName != nil ? recordedAudioDuration : nil
        )

        didSubmitReport = true
        modelContext.insert(newIncident)
        dismiss()
    }
}
