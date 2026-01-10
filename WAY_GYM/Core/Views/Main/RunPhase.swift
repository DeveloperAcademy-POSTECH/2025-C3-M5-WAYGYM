//
//  RunPhase.swift
//  WAY_GYM
//
//  Created by 이주현 on 1/9/26.
//
import CoreFoundation

enum RunPhase: Equatable {
    /// 기본, 결과 모달 닫았을 때 활성화
    case root
    
    // countingDown - 런닝 재생 시 뜨는 3,2,1 화면.
    /// 재생 버튼 탭할 시, isCountingDown == true일 때 활성화
    case countingDown(Int)
    /// 카운트다운 종료시
    case running // 런닝 중
    
    /// 정지 버튼 길게 누르기 시작했을때  활성화
    case finishing(progress: CGFloat) // 길게 눌러 런닝 종료 중일 때
    
    /// 길게 누른 후 손 땠을 때 활성화
    case runResult
}
