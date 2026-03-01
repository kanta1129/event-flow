//
//  ParticipantListView.swift
//  EventFlow
//
//  参加者一覧表示と集金管理画面
//  Requirements: 5.5, 9.3, 10.1, 10.2, 10.3, 10.4, 10.6
//

import SwiftUI

/// 参加者一覧表示と集金管理画面
/// 参加者の追加、編集、削除、支払いステータス表示、催促メッセージ生成を提供
struct ParticipantListView: View {
    
    // MARK: - State Properties
    
    @ObservedObject var participantViewModel: ParticipantViewModel
    let eventId: String
    let eventDate: Date?
    let isEmbedded: Bool
    
    @State private var showingAddParticipant = false
    @State private var editingParticipant: Participant?
    @State private var filterPaymentStatus: PaymentStatus?
    @State private var showingDeleteConfirmation = false
    @State private var participantToDelete: Participant?
    @State private var showingReminderMessage = false
    @State private var selectedParticipantForReminder: Participant?
    @State private var generatedReminderMessage: String = ""
    @State private var isGeneratingReminder = false
    
    // MARK: - Initialization
    
    init(
        participantViewModel: ParticipantViewModel,
        eventId: String,
        eventDate: Date?,
        isEmbedded: Bool = false
    ) {
        self.participantViewModel = participantViewModel
        self.eventId = eventId
        self.eventDate = eventDate
        self.isEmbedded = isEmbedded
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // 集金サマリーカード
            if !isEmbedded {
                paymentSummaryCard
                    .padding()
            }
            
            // フィルターセクション
            filterSection
            
            // 参加者リスト
            if filteredParticipants.isEmpty {
                emptyStateView
            } else {
                participantList
            }
        }
        .if(!isEmbedded) { view in
            view
                .navigationTitle("参加者")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        addButton
                    }
                }
        }
        .sheet(isPresented: $showingAddParticipant) {
            ParticipantFormView(
                eventId: eventId,
                participantViewModel: participantViewModel,
                mode: .add
            )
        }
        .sheet(item: $editingParticipant) { participant in
            ParticipantFormView(
                eventId: eventId,
                participantViewModel: participantViewModel,
                mode: .edit(participant)
            )
        }
        .sheet(isPresented: $showingReminderMessage) {
            ReminderMessageView(
                message: generatedReminderMessage,
                participantName: selectedParticipantForReminder?.name ?? ""
            )
        }
        .alert("参加者を削除", isPresented: $showingDeleteConfirmation) {
            Button("キャンセル", role: .cancel) {}
            Button("削除", role: .destructive) {
                if let participant = participantToDelete {
                    deleteParticipant(participant)
                }
            }
        } message: {
            if let participant = participantToDelete {
                Text("「\(participant.name)」を削除してもよろしいですか？")
            }
        }
    }
    
    // MARK: - Payment Summary Card
    
    /// 集金サマリーカード
    /// Requirements: 10.1, 10.2, 10.3
    private var paymentSummaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("集金状況")
                    .font(.headline)
                
                Spacer()
                
                // 完了率
                Text("\(Int(participantViewModel.completionPercentage() * 100))%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(completionColor)
            }
            
            // 進捗バー
            ProgressView(value: participantViewModel.completionPercentage())
                .tint(completionColor)
            
            // 金額サマリー
            HStack(spacing: 0) {
                // 期待額
                VStack(alignment: .leading, spacing: 4) {
                    Text("期待額")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("¥\(Int(participantViewModel.totalExpected))")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // 回収済み
                VStack(alignment: .leading, spacing: 4) {
                    Text("回収済み")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("¥\(Int(participantViewModel.totalCollected))")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // 未回収
                VStack(alignment: .leading, spacing: 4) {
                    Text("未回収")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("¥\(Int(participantViewModel.outstandingPayment()))")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Filter Section
    
    /// フィルターセクション
    /// Requirements: 10.4
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // すべて表示
                FilterChip(
                    title: "すべて",
                    count: participantViewModel.participants.count,
                    isSelected: filterPaymentStatus == nil,
                    color: .gray
                ) {
                    filterPaymentStatus = nil
                }
                
                // 未払い
                FilterChip(
                    title: "未払い",
                    count: participantViewModel.unpaidParticipants().count,
                    isSelected: filterPaymentStatus == .unpaid,
                    color: .red
                ) {
                    filterPaymentStatus = .unpaid
                }
                
                // 支払い済み
                FilterChip(
                    title: "支払い済み",
                    count: participantViewModel.paidParticipants().count,
                    isSelected: filterPaymentStatus == .paid,
                    color: .green
                ) {
                    filterPaymentStatus = .paid
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Participant List
    
    /// 参加者リスト
    /// Requirements: 5.5, 10.4
    private var participantList: some View {
        List {
            ForEach(filteredParticipants) { participant in
                ParticipantRowView(participant: participant)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingParticipant = participant
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        // 削除アクション
                        Button(role: .destructive) {
                            participantToDelete = participant
                            showingDeleteConfirmation = true
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                        
                        // 編集アクション
                        Button {
                            editingParticipant = participant
                        } label: {
                            Label("編集", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        // 催促メッセージ生成アクション（未払いの場合のみ）
                        if participant.paymentStatus == .unpaid {
                            Button {
                                generateReminderMessage(for: participant)
                            } label: {
                                Label("催促", systemImage: "bell.fill")
                            }
                            .tint(.orange)
                        }
                    }
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - Empty State View
    
    /// 空状態ビュー
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 64))
                .foregroundColor(.gray.opacity(0.5))
            
            Text(emptyStateMessage)
                .font(.headline)
                .foregroundColor(.secondary)
            
            if filterPaymentStatus != nil {
                Button("フィルターをクリア") {
                    filterPaymentStatus = nil
                }
                .buttonStyle(.bordered)
            } else {
                Button("最初の参加者を追加") {
                    showingAddParticipant = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Add Button
    
    /// 参加者追加ボタン
    /// Requirements: 9.1
    private var addButton: some View {
        Button(action: {
            showingAddParticipant = true
        }) {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .semibold))
        }
    }
    
    // MARK: - Computed Properties
    
    /// フィルタリングされた参加者
    private var filteredParticipants: [Participant] {
        if let status = filterPaymentStatus {
            return participantViewModel.participants.filter { $0.paymentStatus == status }
        }
        return participantViewModel.participants
    }
    
    /// 空状態メッセージ
    private var emptyStateMessage: String {
        if let status = filterPaymentStatus {
            switch status {
            case .unpaid:
                return "未払いの参加者はいません"
            case .paid:
                return "支払い済みの参加者はいません"
            }
        }
        return "参加者がまだいません"
    }
    
    /// 完了率に応じた色
    private var completionColor: Color {
        let percentage = participantViewModel.completionPercentage()
        if percentage >= 1.0 {
            return .green
        } else if percentage >= 0.5 {
            return .orange
        } else {
            return .red
        }
    }
    
    // MARK: - Private Methods
    
    /// 参加者を削除
    /// Requirements: 9.4
    private func deleteParticipant(_ participant: Participant) {
        Task {
            await participantViewModel.deleteParticipant(participantId: participant.id, eventId: eventId)
        }
    }
    
    /// 催促メッセージを生成
    /// Requirements: 7.1, 10.6
    private func generateReminderMessage(for participant: Participant) {
        isGeneratingReminder = true
        selectedParticipantForReminder = participant
        
        Task {
            // 未完了タスクは空配列として渡す（タスク情報は別途管理）
            let message = await participantViewModel.generateReminderMessage(
                participantId: participant.id,
                eventDate: eventDate,
                incompleteTasks: []
            )
            
            isGeneratingReminder = false
            
            if let message = message {
                generatedReminderMessage = message
                showingReminderMessage = true
            }
        }
    }
}

// MARK: - Supporting Views

/// 参加者行ビュー
/// Requirements: 5.5, 10.4
struct ParticipantRowView: View {
    let participant: Participant
    
    var body: some View {
        HStack(spacing: 12) {
            // 支払いステータスインジケーター
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            
            VStack(alignment: .leading, spacing: 6) {
                // 名前と支払いステータス
                HStack {
                    Text(participant.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // 支払いステータスバッジ
                    PaymentStatusBadge(status: participant.paymentStatus)
                }
                
                // 期待支払い額と実際の支払い額
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("期待額")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("¥\(Int(participant.expectedPayment))")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    if participant.paymentStatus == .paid {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("支払い額")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("¥\(Int(participant.paidAmount))")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                // 参加日時
                Text("参加日時: \(formatDate(participant.joinedAt))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    /// ステータスカラー
    /// Requirements: 5.6
    private var statusColor: Color {
        switch participant.paymentStatus {
        case .unpaid: return .red
        case .paid: return .green
        }
    }
    
    /// 日付フォーマット
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

/// 支払いステータスバッジ
/// Requirements: 10.4
struct PaymentStatusBadge: View {
    let status: PaymentStatus
    
    var body: some View {
        Text(statusText)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(6)
    }
    
    private var statusText: String {
        switch status {
        case .unpaid: return "未払い"
        case .paid: return "支払い済み"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .unpaid: return .red
        case .paid: return .green
        }
    }
}

/// 参加者フォームビュー
/// Requirements: 9.1, 9.5
struct ParticipantFormView: View {
    
    enum Mode {
        case add
        case edit(Participant)
        
        var title: String {
            switch self {
            case .add: return "参加者を追加"
            case .edit: return "参加者を編集"
            }
        }
    }
    
    let eventId: String
    @ObservedObject var participantViewModel: ParticipantViewModel
    let mode: Mode
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var expectedPayment: String = ""
    @State private var paymentStatus: PaymentStatus = .unpaid
    @State private var paidAmount: String = ""
    @State private var isSaving = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本情報") {
                    TextField("名前", text: $name)
                    
                    TextField("期待支払い額", text: $expectedPayment)
                        .keyboardType(.numberPad)
                }
                
                Section("支払い状況") {
                    Picker("支払いステータス", selection: $paymentStatus) {
                        Text("未払い").tag(PaymentStatus.unpaid)
                        Text("支払い済み").tag(PaymentStatus.paid)
                    }
                    
                    if paymentStatus == .paid {
                        TextField("実際の支払い額", text: $paidAmount)
                            .keyboardType(.numberPad)
                    }
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveParticipant()
                    }
                    .disabled(!isValid || isSaving)
                }
            }
            .onAppear {
                loadParticipantData()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !expectedPayment.isEmpty &&
        Double(expectedPayment) != nil &&
        (paymentStatus == .unpaid || (paymentStatus == .paid && Double(paidAmount) != nil))
    }
    
    // MARK: - Private Methods
    
    private func loadParticipantData() {
        if case .edit(let participant) = mode {
            name = participant.name
            expectedPayment = String(Int(participant.expectedPayment))
            paymentStatus = participant.paymentStatus
            paidAmount = String(Int(participant.paidAmount))
        }
    }
    
    private func saveParticipant() {
        isSaving = true
        
        Task {
            let expectedPaymentValue = Double(expectedPayment) ?? 0.0
            let paidAmountValue = paymentStatus == .paid ? (Double(paidAmount) ?? 0.0) : 0.0
            
            switch mode {
            case .add:
                let newParticipant = Participant(
                    id: UUID().uuidString,
                    name: name.trimmingCharacters(in: .whitespaces),
                    expectedPayment: expectedPaymentValue,
                    paymentStatus: paymentStatus,
                    paidAmount: paidAmountValue,
                    joinedAt: Date(),
                    updatedAt: Date()
                )
                await participantViewModel.addParticipant(newParticipant, eventId: eventId)
                
            case .edit(let existingParticipant):
                let updatedParticipant = Participant(
                    id: existingParticipant.id,
                    name: name.trimmingCharacters(in: .whitespaces),
                    expectedPayment: expectedPaymentValue,
                    paymentStatus: paymentStatus,
                    paidAmount: paidAmountValue,
                    joinedAt: existingParticipant.joinedAt,
                    updatedAt: Date()
                )
                await participantViewModel.updateParticipant(updatedParticipant, eventId: eventId)
            }
            
            isSaving = false
            dismiss()
        }
    }
}

/// 催促メッセージビュー
/// Requirements: 7.1, 7.4, 7.5, 7.6
struct ReminderMessageView: View {
    let message: String
    let participantName: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingCopiedAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // メッセージプレビュー
                VStack(alignment: .leading, spacing: 12) {
                    Text("催促メッセージ")
                        .font(.headline)
                    
                    Text(message)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
                .padding()
                
                // アクションボタン
                VStack(spacing: 12) {
                    // クリップボードにコピー
                    Button(action: {
                        UIPasteboard.general.string = message
                        showingCopiedAlert = true
                    }) {
                        Label("クリップボードにコピー", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    
                    // LINEで共有
                    Button(action: {
                        shareThroughLine()
                    }) {
                        HStack {
                            Image(systemName: "message.fill")
                            Text("LINEで送信")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle(participantName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .alert("コピーしました", isPresented: $showingCopiedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("メッセージをクリップボードにコピーしました")
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// LINE URL Schemeを使用してメッセージを共有
    /// Requirements: 7.6
    private func shareThroughLine() {
        let encodedMessage = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let lineURLString = "line://msg/text/\(encodedMessage)"
        
        if let lineURL = URL(string: lineURLString) {
            if UIApplication.shared.canOpenURL(lineURL) {
                UIApplication.shared.open(lineURL)
            } else {
                // LINEがインストールされていない場合は通常の共有シートを表示
                let activityVC = UIActivityViewController(
                    activityItems: [message],
                    applicationActivities: nil
                )
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first?.rootViewController {
                    rootViewController.present(activityVC, animated: true)
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ParticipantListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ParticipantListView(
                participantViewModel: previewParticipantViewModel(),
                eventId: "preview-event-id",
                eventDate: Date()
            )
        }
    }
    
    static func previewParticipantViewModel() -> ParticipantViewModel {
        let mockRepository = MockParticipantRepository()
        let mockAIService = MockAIService()
        let viewModel = ParticipantViewModel(
            participantRepository: mockRepository,
            aiService: mockAIService
        )
        
        viewModel.participants = [
            Participant(
                id: "1",
                name: "田中太郎",
                expectedPayment: 5000,
                paymentStatus: .paid,
                paidAmount: 5000,
                joinedAt: Date(),
                updatedAt: Date()
            ),
            Participant(
                id: "2",
                name: "佐藤花子",
                expectedPayment: 5000,
                paymentStatus: .paid,
                paidAmount: 5000,
                joinedAt: Date(),
                updatedAt: Date()
            ),
            Participant(
                id: "3",
                name: "鈴木一郎",
                expectedPayment: 5000,
                paymentStatus: .unpaid,
                paidAmount: 0,
                joinedAt: Date(),
                updatedAt: Date()
            ),
            Participant(
                id: "4",
                name: "高橋美咲",
                expectedPayment: 5000,
                paymentStatus: .unpaid,
                paidAmount: 0,
                joinedAt: Date(),
                updatedAt: Date()
            )
        ]
        
        return viewModel
    }
}

class MockParticipantRepository: ParticipantRepository {
    func addParticipant(_ participant: Participant, eventId: String) async throws -> String {
        return participant.id
    }
    
    func getParticipant(participantId: String, eventId: String) async throws -> Participant {
        throw NSError(domain: "MockError", code: 404, userInfo: nil)
    }
    
    func updateParticipant(_ participant: Participant, eventId: String) async throws {
        // Mock implementation
    }
    
    func deleteParticipant(participantId: String, eventId: String) async throws {
        // Mock implementation
    }
    
    func observeParticipants(eventId: String) -> AsyncStream<[Participant]> {
        return AsyncStream { continuation in
            continuation.finish()
        }
    }
}

class MockAIService: AIService {
    func generateEventTemplate(eventType: String, participantCount: Int, budget: Double?) async throws -> EventTemplate {
        throw NSError(domain: "MockError", code: 404, userInfo: nil)
    }
    
    func generateReminderMessage(context: ReminderContext) async throws -> String {
        return "テスト催促メッセージ"
    }
}
#endif

// MARK: - View Extension

extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
