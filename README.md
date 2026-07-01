output 은 모듈 나눌 때 모듈 내에서 쓰는 값들을 선언하는게 아니라
다른 모듈에서 다른 모듈의 값이 필요로 할 때 그걸 output으로 넣어줘서 쓸 수 있게 해주는거임


루트 variables.tf 선언
        ↓
루트 main.tf module 블록에서 전달
        ↓
자식 variables.tf에 선언되어 있어야 받을 수 있음
        ↓
자식 main.tf에서 var.xxx로 사용
