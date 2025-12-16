//
//  SocialView.swift
//  WAY_GYM
//
//  Created by 이주현 on 9/30/25.
//
import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

// MARK: - Model
struct RunRecord: Identifiable, Codable {
    @DocumentID var id: String?
    var distanceKm: Double?
    var durationSec: Int?
    var calories: Double?
    var startedAt: Timestamp?
    var memo: String?

    // Derived values with safe defaults
    var startedDate: Date { startedAt?.dateValue() ?? Date.distantPast }
    var distanceText: String { String(format: "%.2f km", distanceKm ?? 0) }
    var durationText: String {
        let sec = max(0, durationSec ?? 0)
        let h = sec / 3600, m = (sec % 3600) / 60, s = sec % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }
    var caloriesText: String { String(format: "%.0f kcal", calories ?? 0) }
}

// MARK: - ViewModel
final class SocialViewModel: ObservableObject {
    @Published var friendUID: String = ""
    @Published var friendInviteCode: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var records: [RunRecord] = []

    private let db = Firestore.firestore()

    /// InviteCode → UID → runRecords
    func fetchFriendRecordsByInviteCode() {
        let code = friendInviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else {
            self.errorMessage = "초대코드를 입력하세요."
            self.records = []
            return
        }
        errorMessage = nil
        isLoading = true

        // 1) Users where inviteCode == code → uid
        let users = db.collection("Users")
        users.whereField("inviteCode", isEqualTo: code)
            .limit(to: 1)
            .getDocuments { [weak self] snap, err in
                guard let self = self else { return }
                if let err = err {
                    self.isLoading = false
                    self.errorMessage = "초대코드 조회 실패: \(err.localizedDescription)"
                    return
                }
                guard let doc = snap?.documents.first else {
                    self.isLoading = false
                    self.errorMessage = "해당 초대코드의 사용자를 찾을 수 없습니다."
                    return
                }
                let uid = doc.documentID
                self.friendUID = uid
                // 2) With uid, fetch run records
                self.fetchFriendRecordsByUID(uid)
            }
    }

    /// Direct UID path fetch (used internally after resolving invite code)
    func fetchFriendRecordsByUID(_ uidParam: String? = nil) {
        let uid = (uidParam ?? friendUID).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !uid.isEmpty else {
            self.isLoading = false
            self.errorMessage = "UID가 비었습니다."
            self.records = []
            return
        }

        let colRef = db.collection("RunRecordModels").document(uid).collection("runRecords")
        colRef
            .limit(to: 50)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                self.isLoading = false
                if let error = error {
                    self.errorMessage = "불러오기 실패: \(error.localizedDescription)"
                    self.records = []
                    return
                }
                guard let snapshot = snapshot else {
                    self.errorMessage = "스냅샷이 비었습니다."
                    self.records = []
                    return
                }
                do {
                    self.records = try snapshot.documents.compactMap { doc in
                        try doc.data(as: RunRecord.self)
                    }
                    if self.records.isEmpty { self.errorMessage = "기록이 없습니다." }
                } catch {
                    self.errorMessage = "파싱 오류: \(error.localizedDescription)"
                    self.records = []
                }
            }
    }
}

// MARK: - View
struct SocialView: View {
    @StateObject private var vm = SocialViewModel()
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            // Input Row
            HStack(spacing: 8) {
                TextField("친구 초대코드를 입력하세요 (inviteCode)", text: $vm.friendInviteCode)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .keyboardType(.asciiCapable)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).strokeBorder(.gray.opacity(0.3)))
                    .focused($isFieldFocused)

                Button {
                    isFieldFocused = false
                    vm.fetchFriendRecordsByInviteCode()
                } label: {
                    Text("확인")
                        .fontWeight(.semibold)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.15)))
                }
                .buttonStyle(.plain)
                .disabled(vm.friendInviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if !vm.friendUID.isEmpty {
                Text("대상 UID: \(vm.friendUID)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Loading / Error
            if vm.isLoading {
                ProgressView("불러오는 중…")
                    .padding(.top, 8)
            } else if let msg = vm.errorMessage, !msg.isEmpty {
                Text(msg)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            // List
            List(vm.records) { record in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(record.distanceText)
                        Text("·")
                        Text(record.durationText)
                        Text("·")
                        Text(record.caloriesText)
                    }
                    .font(.headline)

                    Text(dateString(record.startedDate))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let memo = record.memo, !memo.isEmpty {
                        Text(memo)
                            .font(.subheadline)
                    }
                }
                .padding(.vertical, 6)
            }
            .listStyle(.plain)
        }
        .padding(16)
        .navigationTitle("친구 기록 보기")
    }

    // MARK: - Helpers
    private func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy.MM.dd (E) a h:mm"
        return f.string(from: date)
    }
}

#Preview {
    NavigationStack {
        SocialView()
    }
}
