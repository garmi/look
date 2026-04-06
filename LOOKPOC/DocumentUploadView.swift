import PDFKit
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum UploadDocumentType {
    case bloodReport
    case prescription

    var title: String {
        switch self {
        case .bloodReport:
            return "Blood Report"
        case .prescription:
            return "Prescription"
        }
    }

    var systemPrompt: String {
        switch self {
        case .bloodReport:
            return """
            You are a medical document parser for the LOOK kidney transplant app.
            Extract blood test values from this document.
            Return ONLY valid JSON, no other text:
            {
              "reportDate": "DD MMM YYYY or Unknown",
              "values": [
                {
                  "name": "test name",
                  "value": "numeric value",
                  "unit": "unit of measurement",
                  "referenceRange": "normal range from report",
                  "status": "normal|low|high|critical",
                  "lookNote": "one plain-language sentence about what this means for a transplant patient - never say normal/abnormal alone, always add context"
                }
              ],
              "lookSummary": "2-sentence plain English summary for a patient",
              "flaggedValues": ["list any values that warrant medical attention"],
              "disclaimer": "These values are extracted for your reference. Always discuss with your transplant team."
            }
            Focus on: Creatinine, eGFR, Tacrolimus trough, Haemoglobin, Potassium, Sodium, Uric acid, Blood pressure if present, HbA1c if present.
            If a value is not present, omit it.
            """
        case .prescription:
            return """
            You are a prescription parser for the LOOK kidney transplant app.
            Extract medication information from this prescription image or PDF.
            Return ONLY valid JSON, no other text:
            {
              "prescribedDate": "DD MMM YYYY or Unknown",
              "doctorName": "doctor name or Unknown",
              "medications": [
                {
                  "name": "medication name",
                  "dose": "dose amount and unit",
                  "frequency": "how many times per day",
                  "timing": "morning/evening/with food etc",
                  "duration": "number of days or ongoing",
                  "lookNote": "one plain-language note about this medication for a transplant patient"
                }
              ],
              "instructions": "any special instructions from prescription",
              "disclaimer": "Always follow your doctor's prescription exactly. Do not change doses without consulting your doctor."
            }
            """
        }
    }
}

struct ExtractedValue: Identifiable {
    let id = UUID()
    var name: String
    var value: String
    var unit: String
    var status: String
    var lookNote: String
}

struct DocumentUploadView: View {
    let documentType: UploadDocumentType
    @Binding var isPresented: Bool

    @State private var uploadState: UploadState = .idle
    @State private var extractedValues: [ExtractedValue] = []
    @State private var summaryText: String = ""
    @State private var flaggedValues: [String] = []
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var showFilePicker = false
    @State private var selectedImage: UIImage?
    @State private var progress: Double = 0
    @State private var errorMessage: String = ""
    @State private var sourceDateLabel: String = "Unknown"
    @State private var extractionMode: ExtractionMode = .ai

    enum UploadState {
        case idle
        case processing
        case extracted
        case saved
        case error
    }

    enum ExtractionMode {
        case ai
        case betaFallback
    }

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(documentType.title)
                        .font(.custom("DM Serif Display", size: 22))
                        .foregroundColor(Color(red: 0.11, green: 0.11, blue: 0.18))
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    Text(headerText)
                        .font(.system(size: 13, weight: .light))
                        .foregroundColor(Color(red: 0.61, green: 0.55, blue: 0.50))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                        .lineSpacing(3)

                    if uploadState == .processing {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color(red: 0.95, green: 0.94, blue: 0.92))

                                Rectangle()
                                    .fill(Color(red: 0.00, green: 0.48, blue: 0.48))
                                    .frame(width: geometry.size.width * progress)
                                    .animation(.easeInOut(duration: 0.3), value: progress)
                            }
                        }
                        .frame(height: 3)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                    }

                    if uploadState == .extracted || uploadState == .saved {
                        if extractionMode == .betaFallback {
                            HStack(alignment: .top, spacing: 8) {
                                Text("Beta mode")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Color(red: 0.00, green: 0.48, blue: 0.48))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color(red: 0.00, green: 0.48, blue: 0.48).opacity(0.08))
                                    .clipShape(Capsule())

                                Text("This build saved the document flow, but did not run secure AI extraction.")
                                    .font(.system(size: 11, weight: .light))
                                    .foregroundColor(Color(red: 0.61, green: 0.55, blue: 0.50))
                                    .lineSpacing(3)
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)
                        }

                        VStack(spacing: 6) {
                            ForEach(extractedValues) { value in
                                HStack(alignment: .top) {
                                    Text(value.name)
                                        .font(.system(size: 13))
                                        .foregroundColor(Color(red: 0.11, green: 0.11, blue: 0.18))

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("\(value.value) \(value.unit)".trimmingCharacters(in: .whitespaces))
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(statusColor(value.status))

                                        Text(value.lookNote)
                                            .font(.system(size: 10, weight: .light))
                                            .foregroundColor(Color(red: 0.71, green: 0.66, blue: 0.60))
                                            .multilineTextAlignment(.trailing)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)

                                if value.id != extractedValues.last?.id {
                                    Divider()
                                        .padding(.horizontal, 20)
                                        .opacity(0.5)
                                }
                            }
                        }
                        .background(Color(red: 0.98, green: 0.97, blue: 0.95))
                        .cornerRadius(14)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)

                        if !flaggedValues.isEmpty {
                            HStack(alignment: .top, spacing: 8) {
                                Text("⚠️")
                                Text("Values worth discussing with your doctor: \(flaggedValues.joined(separator: ", "))")
                                    .font(.system(size: 11, weight: .light))
                                    .foregroundColor(Color(red: 0.78, green: 0.41, blue: 0.23))
                                    .lineSpacing(3)
                            }
                            .padding(12)
                            .background(Color(red: 0.91, green: 0.53, blue: 0.23).opacity(0.08))
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 10)
                        }

                        Text("Always confirm these values with your transplant team. LOOK does not diagnose.")
                            .font(.system(size: 10, weight: .light))
                            .foregroundColor(Color(red: 0.77, green: 0.73, blue: 0.69))
                            .italic()
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)
                            .lineSpacing(3)
                    }

                    Spacer(minLength: 16)
                }
            }

            VStack(spacing: 8) {
                actionButtons

                Button("Cancel") {
                    isPresented = false
                }
                .font(.system(size: 13))
                .foregroundColor(Color(red: 0.71, green: 0.66, blue: 0.60))
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .background(Color(red: 0.98, green: 0.98, blue: 0.97))
        .sheet(isPresented: $showImagePicker) {
            ImagePickerView(image: $selectedImage, onSelected: processImage)
        }
        .sheet(isPresented: $showCamera) {
            CameraView(image: $selectedImage, onCaptured: processImage)
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.pdf, .image, .jpeg, .png],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    processFileURL(url)
                }
            case .failure:
                uploadState = .error
                errorMessage = "Could not open that file. Try a PDF or image."
            }
        }
    }

    private var headerText: String {
        switch uploadState {
        case .idle:
            return "Take a photo or upload a file. LOOK extracts the key information automatically when AI parsing is configured. Until then, uploads can still be saved in beta mode."
        case .processing:
            return "Reading your document..."
        case .extracted:
            return summaryText
        case .saved:
            return "Saved to your health record."
        case .error:
            return errorMessage
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch uploadState {
        case .idle:
            uploadButton(title: "📷  Take Photo", isPrimary: true) {
                showCamera = true
            }
            uploadButton(title: "📁  Choose from Files", isPrimary: false) {
                showFilePicker = true
            }
            uploadButton(title: "🖼️  Photo Library", isPrimary: false) {
                showImagePicker = true
            }
        case .processing:
            uploadButton(title: "Processing...", isPrimary: true) {}
                .disabled(true)
                .opacity(0.5)
        case .extracted:
            uploadButton(title: extractionMode == .betaFallback ? "Save Placeholder Record" : "Save to Health Record", isPrimary: true) {
                saveToHealthRecord()
            }
            uploadButton(title: "Retake / Upload Again", isPrimary: false) {
                uploadState = .idle
                extractedValues = []
                summaryText = ""
                flaggedValues = []
                selectedImage = nil
                progress = 0
            }
        case .saved:
            uploadButton(title: "Done", isPrimary: true) {
                isPresented = false
            }
        case .error:
            uploadButton(title: "Try Again", isPrimary: true) {
                uploadState = .idle
                progress = 0
                extractedValues = []
                summaryText = ""
                flaggedValues = []
            }
        }
    }

    func uploadButton(title: String, isPrimary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isPrimary ? Color(red: 0.11, green: 0.11, blue: 0.18) : Color(red: 0.93, green: 0.92, blue: 0.91))
                .foregroundColor(isPrimary ? .white : Color(red: 0.11, green: 0.11, blue: 0.18))
                .cornerRadius(14)
        }
    }

    func statusColor(_ status: String) -> Color {
        switch status {
        case "normal":
            return Color(red: 0.29, green: 0.49, blue: 0.35)
        case "low", "high":
            return Color(red: 0.78, green: 0.41, blue: 0.23)
        case "critical":
            return Color(red: 0.70, green: 0.20, blue: 0.20)
        default:
            return Color(red: 0.11, green: 0.11, blue: 0.18)
        }
    }

    func processImage(_ image: UIImage) {
        selectedImage = image
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        let base64 = imageData.base64EncodedString()
        callClaudeAPI(imageBase64: base64, mimeType: "image/jpeg")
    }

    func processFileURL(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        let ext = url.pathExtension.lowercased()
        if ext == "pdf" {
            if let pdfDoc = PDFDocument(url: url),
               let page = pdfDoc.page(at: 0) {
                let pageRect = page.bounds(for: .mediaBox)
                let scale: CGFloat = 2.0
                let renderer = UIGraphicsImageRenderer(size: CGSize(width: pageRect.width * scale, height: pageRect.height * scale))
                let image = renderer.image { context in
                    UIColor.white.setFill()
                    context.fill(CGRect(origin: .zero, size: CGSize(width: pageRect.width * scale, height: pageRect.height * scale)))
                    context.cgContext.scaleBy(x: scale, y: scale)
                    page.draw(with: .mediaBox, to: context.cgContext)
                }
                processImage(image)
            }
        } else if let data = try? Data(contentsOf: url),
                  let image = UIImage(data: data) {
            processImage(image)
        } else {
            uploadState = .error
            errorMessage = "Could not read that file. Try a clearer photo or PDF."
        }
    }

    func callClaudeAPI(imageBase64: String, mimeType: String) {
        guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !apiKey.isEmpty else {
            applyBetaFallbackExtraction()
            return
        }

        extractionMode = .ai
        uploadState = .processing
        progress = 0

        let timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { timer in
            DispatchQueue.main.async {
                if progress < 0.88 {
                    progress += Double.random(in: 0.06...0.14)
                } else {
                    timer.invalidate()
                }
            }
        }

        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            timer.invalidate()
            uploadState = .error
            errorMessage = "Could not reach the document parser service."
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 1500,
            "system": documentType.systemPrompt,
            "messages": [[
                "role": "user",
                "content": [[
                    "type": "image",
                    "source": [
                        "type": "base64",
                        "media_type": mimeType,
                        "data": imageBase64
                    ]
                ], [
                    "type": "text",
                    "text": "Extract the information from this \(documentType.title.lowercased()) document."
                ]]
            ]]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, _, _ in
            timer.invalidate()
            DispatchQueue.main.async {
                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let content = json["content"] as? [[String: Any]],
                      let text = content.first?["text"] as? String else {
                    applyBetaFallbackExtraction()
                    return
                }

                parseExtractedJSON(text)
                progress = 1.0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    uploadState = .extracted
                }
            }
        }
        .resume()
    }

    func parseExtractedJSON(_ text: String) {
        let clean = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = clean.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            applyBetaFallbackExtraction()
            return
        }

        extractionMode = .ai
        summaryText = json["lookSummary"] as? String ?? ""
        flaggedValues = json["flaggedValues"] as? [String] ?? []
        sourceDateLabel = documentType == .bloodReport
            ? (json["reportDate"] as? String ?? "Unknown")
            : (json["prescribedDate"] as? String ?? "Unknown")

        switch documentType {
        case .bloodReport:
            if let values = json["values"] as? [[String: Any]] {
                extractedValues = values.map { value in
                    ExtractedValue(
                        name: value["name"] as? String ?? "",
                        value: value["value"] as? String ?? "",
                        unit: value["unit"] as? String ?? "",
                        status: value["status"] as? String ?? "normal",
                        lookNote: value["lookNote"] as? String ?? ""
                    )
                }
            }
        case .prescription:
            if let medications = json["medications"] as? [[String: Any]] {
                extractedValues = medications.map { medication in
                    let dose = medication["dose"] as? String ?? ""
                    let frequency = medication["frequency"] as? String ?? ""
                    return ExtractedValue(
                        name: medication["name"] as? String ?? "",
                        value: "\(dose) · \(frequency)".trimmingCharacters(in: .whitespaces),
                        unit: medication["timing"] as? String ?? "",
                        status: "normal",
                        lookNote: medication["lookNote"] as? String ?? ""
                    )
                }
            }
        }

        if extractedValues.isEmpty {
            applyBetaFallbackExtraction()
        }
    }

    func saveToHealthRecord() {
        let record = HealthRecordStore.makeRecord(
            type: documentType == .bloodReport ? .bloodReport : .prescription,
            sourceDateLabel: sourceDateLabel,
            summary: summaryText,
            flaggedValues: flaggedValues,
            extractedValues: extractedValues
        )
        HealthRecordStore.append(record)
        uploadState = .saved
    }

    private func applyBetaFallbackExtraction() {
        extractionMode = .betaFallback
        progress = 1.0
        sourceDateLabel = "Captured \(Date.now.formatted(date: .abbreviated, time: .omitted))"
        flaggedValues = []

        switch documentType {
        case .bloodReport:
            summaryText = "Blood report captured in beta mode. This build does not have live AI parsing configured yet, so the report is saved as a document placeholder for workflow review."
            extractedValues = [
                ExtractedValue(
                    name: "Report capture",
                    value: "Saved",
                    unit: "beta mode",
                    status: "normal",
                    lookNote: "The upload flow worked. Extraction should move to a secure backend before external rollout."
                )
            ]
        case .prescription:
            summaryText = "Prescription captured in beta mode. This build does not have live AI parsing configured yet, so the prescription is saved as a document placeholder for workflow review."
            extractedValues = [
                ExtractedValue(
                    name: "Prescription capture",
                    value: "Saved",
                    unit: "beta mode",
                    status: "normal",
                    lookNote: "The upload flow worked. Extraction should move to a secure backend before external rollout."
                )
            ]
        }

        uploadState = .extracted
    }
}

struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var onSelected: (UIImage) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1

        let controller = PHPickerViewController(configuration: configuration)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePickerView

        init(_ parent: ImagePickerView) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }

            provider.loadObject(ofClass: UIImage.self) { image, _ in
                guard let uiImage = image as? UIImage else { return }
                DispatchQueue.main.async {
                    self.parent.image = uiImage
                    self.parent.onSelected(uiImage)
                }
            }
        }
    }
}

struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var onCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        controller.delegate = context.coordinator
        controller.allowsEditing = false
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            picker.dismiss(animated: true)
            guard let uiImage = info[.originalImage] as? UIImage else { return }
            parent.image = uiImage
            parent.onCaptured(uiImage)
        }
    }
}
