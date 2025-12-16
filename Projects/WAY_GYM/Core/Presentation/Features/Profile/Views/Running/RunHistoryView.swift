import SwiftUI

struct RunHistoryView: View {
    @StateObject private var viewModel = RunHistoryViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.gang_bg_primary_5
                    .ignoresSafeArea()
                
                VStack {
                    CustomNavigationBar(title: "구역 순찰 기록")
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 13) {
                            if viewModel.isLoading {
                                Text("데이터를 불러오는 중입니다...")
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.gray)
                                    .padding()
                            } else {
                                ForEach(viewModel.sections) { section in
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(section.monthLabel)
                                            .font(.title02)
                                        HStack {
                                            Text(section.runCountText)
                                            Text(section.totalAreaText)
                                            Text(section.totalDistanceText)
                                        }
                                    }
                                    .font(.text02)
                                    .foregroundColor(.gang_text_1)
                                    .padding(.leading, 5)
                                    
                                    ForEach(section.runs) { summary in
                                        RunCardView(summary: summary) { tapped in
                                            viewModel.selectCard(tapped)
                                        }
                                    }
                                    
                                    Spacer().frame(height: 4)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        
                    }
                    
                }
            }
            
            NavigationLink(
                destination: viewModel.selected.map { summary in
                    AnyView(
                        RunDetailView(viewModel: RunDetailViewModel(summary: summary))
                            .foregroundColor(Color.gang_text_2)
                            .font(.title01)
                    )
                } ?? AnyView(EmptyView()),
                isActive: Binding(
                    get: { viewModel.selected != nil },
                    set: { active in if !active { viewModel.selected = nil } }
                    ),
                label: { EmptyView() }
            )
            .hidden()
            
        }
        .onAppear {
            viewModel.loadAllRuns()
        }
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    RunHistoryView()
        .foregroundColor(Color.gang_text_2)
        .font(.title01)
}
