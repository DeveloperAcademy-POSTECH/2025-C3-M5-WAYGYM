//
//  AddressPickerSheet.swift
//  WAY_GYM
//
//  Created by 이주현 on 1/15/26.
//

import SwiftUI

struct AddressPickerSheet: View {
    let data: [SidoNode]
    let onConfirm: (String, String, String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var sidoIndex: Int = 0
    @State private var sigunguIndex: Int = 0
    @State private var dongIndex: Int = 0

    var body: some View {
        ZStack {
            Color.gangBgPrimary5
                .ignoresSafeArea()
            
            VStack(spacing: 14) {
                HStack {
                    Text("주소 선택")
                        .font(.title03)

                    Spacer()

                    Button("닫기") { dismiss() }
                        .font(.text02)
                        .foregroundStyle(Color.gangText2.opacity(0.8))
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black.opacity(0.35))
                    .overlay(
                        HStack(spacing: 0) {
                            pickerColumn(
                                title: "시/도",
                                items: data.map(\.sido),
                                selection: $sidoIndex
                            )
                            Divider()
                            pickerColumn(
                                title: "구/군",
                                items: currentSigunguList,
                                selection: $sigunguIndex
                            )
                            Divider()
                            pickerColumn(
                                title: "동",
                                items: currentDongList,
                                selection: $dongIndex
                            )
                        }
                        .onChange(of: sidoIndex) {
                            sigunguIndex = 0
                            dongIndex = 0
                        }
                            .onChange(of: sigunguIndex) {
                            dongIndex = 0
                        }
                    )
                    .frame(height: 200)
                    .padding(.horizontal, 16)

                Button {
                    guard !data.isEmpty else { return }
                    let sido = data[sidoIndex].sido
                    let sigungu = currentSigunguList[safe: sigunguIndex] ?? ""
                    let dong = currentDongList[safe: dongIndex] ?? ""
                    onConfirm(sido, sigungu, dong)
                    dismiss()
                } label: {
                    Text("선택 완료")
                        .font(.title03)
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.gangHighlight2)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .presentationDetents([.medium])
        }
    }

    private func pickerColumn(title: String, items: [String], selection: Binding<Int>) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.text02)
                .foregroundStyle(Color.white)

            Picker(title, selection: selection) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, value in
                    Text(value)
                        .tag(idx)
                        .foregroundStyle(Color.gangText1)
                }
            }
            .pickerStyle(.wheel)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .onAppear {
            UIScrollView.appearance().backgroundColor = .clear
        }
    }

    private var currentSigunguList: [String] {
        guard data.indices.contains(sidoIndex) else { return [] }
        return data[sidoIndex].sigungu.map(\.name)
    }

    private var currentDongList: [String] {
        guard data.indices.contains(sidoIndex) else { return [] }
        let sigungu = data[sidoIndex].sigungu
        guard sigungu.indices.contains(sigunguIndex) else { return [] }
        return sigungu[sigunguIndex].dong
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}


#Preview {
    let mockData: [SidoNode] = [
        SidoNode(
            sido: "서울특별시",
            sigungu: [
                SigunguNode(name: "강남구", dong: ["역삼동", "삼성동", "대치동"]),
                SigunguNode(name: "마포구", dong: ["서교동", "합정동", "망원동"])
            ]
        ),
        SidoNode(
            sido: "부산광역시",
            sigungu: [
                SigunguNode(name: "해운대구", dong: ["우동", "중동", "좌동"]),
                SigunguNode(name: "수영구", dong: ["광안동", "남천동", "민락동"])
            ]
        )
    ]

        AddressPickerSheet(data: mockData) { s, g, d in
            print("Selected: \(s) \(g) \(d)")
        }
    .font(.text01)
    .foregroundColor(Color.gangText2)
}
