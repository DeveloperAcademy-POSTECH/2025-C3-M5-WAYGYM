# 동네접수 RUN 

> **🏃‍♀️ 걷는 일상을 ‘점령 활동’으로 바꾸는 게임형 러닝 앱**  
> 강력한 운동 동기가 없는 사람도 움직이게 만드는 GPS 기반 땅따먹기 러닝 서비스

![1](https://github.com/user-attachments/assets/55fa88f1-a159-4dab-aced-1553365450c5)
<img width="4668" height="2626" alt="3" src="https://github.com/user-attachments/assets/2b68241a-a66a-4059-8e47-51d8c8b155df" />

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)]()
[![Xcode](https://img.shields.io/badge/Xcode-15.0-blue.svg)]()
[![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=flat-square&logo=firebase&logoColor=white%22/%3E)]()

---

## 👥 프로젝트 기간 & 참여 인원

### 팀 프로젝트 기간
- **2025.05.08 ~ 2025.06.13**

- 팀 WYA_GYM(Where You At 횐님 어디세요), 나와바리GO
  - PM: 퍼드
  - PM & Designer: 딘
  - Designer: 브랜뉴
  - iOS Developer: 주디제이, 노터, 레오

### 이후 진행
- 아카데미 수료 이후, 주디제이가 단독으로 프로젝트를 이어서 개발 중
- 기존 기획 의도와 디자인을 유지하며 기능 확장, 구조 개선, 출시 준비를 진행하고 있음 (2026년 2월 내 App Store 출시 예정)

---

## 💡 프로젝트 동기 및 기획

**“운동이 필요하다는 건 알지만, 실제 행동으로 이어지지 않는 사람을 어떻게 움직이게 만들 수 있을까?”**  
라는 질문에서 시작된 프로젝트입니다.

출발점은 한 명의 매우 구체적인 사용자였습니다.  
> *운동의 필요성은 인지하고 있지만, 강한 동기가 없어 행동으로 이어지지 않는 약사.*

인터뷰와 사용 패턴 관찰을 통해 다음과 같은 특징을 발견했습니다.

- 게임을 좋아하며, 보상이 숫자가 아닌 **아이템·영역 등 시각적 결과**로 주어질 때 성취감을 느낀다
- 자신의 행동이 **즉각적인 보상으로 전환되는 구조**에 강하게 반응한다
- 별도의 운동은 하지 않으며, **일상 속 ‘걷기’가 유일한 지속 운동**이다

### 핵심 인사이트
> **눈에 띄는 보상이 있어야 움직인다.  
> 이미 하고 있는 ‘걷기’를 멈추지 않게 만들어야 한다.**

이에 대한 해답으로 **GPS 기반 땅따먹기 러닝**을 제안했습니다.

### 핵심 기획 방향
기존 러닝 앱이 수치 중심 기록에 머문다면,  
WAY_GYM은 **러닝을 ‘운동 기록’이 아닌 ‘점령 활동’으로 인식하게 만드는 것**을 목표로 합니다.

- 이동 경로가 **영역(땅)** 으로 남고
- 그 영역이 **성과이자 보상**이 되는 구조

이를 통해 운동을 ‘해야 할 일’이 아니라,  
**점점 확장되는 자신의 활동 영역을 넓히는 행위**로 전환하고자 했습니다.


---

## 🧩 구현 기능

### 1. GPS 기반 땅따먹기 러닝
- 사용자의 이동 경로를 GPS 좌표로 기록
- 이동 경로가 **닫힌 형태(Closed Path)** 를 이루면 영역 생성
- 생성된 영역은 사용자의 **점령 땅**으로 저장 및 시각화

### 2. 러닝 결과 시각화
- 러닝 종료 시 다음 정보를 함께 제공
  - 이동 거리
  - 소요 시간
  - 칼로리
  - **점유 면적(㎡)**
- 숫자 기록 + 지도 기반 시각적 성과를 동시에 제공

### 3. 친구 추가 & 경쟁 구조 (NEW)
- 친구 추가 기능
- 동일 지역에서 **영역 경쟁(점령전)** 가능
- 친구의 영역을 침범하거나,
  더 넓은 영역을 점유하며 경쟁하는 구조

### 4. 확장 가능 구조
- 현재는 개인/친구 단위 플레이 중심
- 추후:
  - 미션 기반 플레이
  - 듀오/팀 점령전
  - 보상 아이템 시스템
  확장을 고려해 데이터 구조 설계

## ⚙️ 설치 및 실행
전체 아키텍처 흐름: FirebaseManager > Repository > (Store) > View/ViewModel
- **FirebaseManager**
  - Firestore / Auth / Storage 접근 관리
  - Firebase 관련 로직 단일 책임
- **Repository**
  - 도메인 단위 데이터 접근 계층
  - User / Friend / RunRecord 등 역할 분리
- **Store**
  - 앱 전역 또는 기능 단위 상태 관리
  - 캐싱 및 상태 공유 담당
- **ViewModel**
  - UI에 필요한 데이터 가공
  - 화면 로직 관리
- **View**
  - SwiftUI 기반 화면
  - 상태 표현에 집중
```
📦WAY_GYM
┣ 📂Resources
┣ 📂Common
┃ ┣ 📂Extensions
┃ ┣ 📂Utils
┃ ┣ 📂Model
┃ ┣ 📂Services
┃ ┃ ┣ 📄LocationManager
┃ ┃ ┗ 📂Firestore
┃ ┃ ┣ 📄FirestorePath
┃ ┃ ┗ 📄FirestoreManager
┃ ┣ 📂Repository
┃ ┃ ┣ 📄UserRepository
┃ ┃ ┣ 📄FriendRepository
┃ ┃ ┗ 📄RunRecordRepository
┣ 📂Presentation
┃ ┣ 📂App
┃ ┣ 📂Store
┃ ┃ ┣ 📄UserStore
┃ ┃ ┣ 📄FriendStore
┃ ┃ ┗ 📄RunRecordStore
┃ ┣ 📂Views
┗ ┗ 📂ViewModels
```


## 🧪 테스트 / 시연

### Firebase 설정

> ⚠️ 본 프로젝트는 Firebase 기반으로 동작합니다.

- `GoogleService-Info.plist` 파일은 보안 및 소유권 관리상 공개하지 않습니다.
- 실행 또는 테스트를 원할 경우, 프로젝트 관리자 및 소유자(주디제이)의 사전 허락이 필요합니다. 개인 연락을 통해 Firebase 설정 파일을 전달받아야 합니다.


## 📬 문의

[![링크드인](http://img.shields.io/badge/-LinkedIn-0072b1?style=flat&logo=linkedin&link=https://www.linkedin.com/in/주현-‎이-612a882b8)](https://www.linkedin.com/in/주현-‎이-612a882b8)
[![이메일](https://img.shields.io/badge/judyjjuhyunlee@gmail.com-168de2?style=for-the-badge&logo=gmail&logoColor=white)](judyjjuhyunlee@gmail.com)
