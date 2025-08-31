import QtQuick 2.15
import QtQuick.Window 2.15

Window {
    visible: true
    width: 500
    height: 500
    title: "Pacman Client"

    property int playerX: 0
    property int playerY: 0
    property int score: 0
    property var otherPlayers: [] // 新增：其他玩家列表

    Connections {
        target: gameClient
        function onUpdatePlayer(x, y, s) {
            console.log("onUpdatePlayer: x =", x, "y =", y, "score =", s)
            playerX = x
            playerY = y
            score = s
        }
        function onUpdateBeans(beans) {
            console.log("onUpdateBeans: beans count =", beans.length)
            beanModel.clear()
            for (var i = 0; i < beans.length; i++) {
                beanModel.append({x: beans[i].x, y: beans[i].y})
            }
        }
        function onUpdateOtherPlayers(players) {
            console.log("onUpdateOtherPlayers: count =", players.length)
            otherPlayers = players
        }
    }

    Rectangle {
        id: grid
        anchors.fill: parent
        color: "black"

        Repeater { model: 11; Rectangle { x: 0; y: index * 50; width: 500; height: 1; color: "gray" } }
        Repeater { model: 11; Rectangle { x: index * 50; y: 0; width: 1; height: 500; color: "gray" } }

        ListModel { id: beanModel }
        Repeater {
            model: beanModel
            Rectangle {
                x: model.x * 50 + 22.5
                y: model.y * 50 + 22.5
                width: 5; height: 5
                color: "yellow"
            }
        }

        Rectangle {
            id: player
            x: playerX * 50 + 15
            y: playerY * 50 + 15
            width: 20; height: 20
            color: "blue"
            radius: 10
            focus: true

            Keys.onPressed: (event) => {
                var newX = playerX
                var newY = playerY
                if (event.key === Qt.Key_W || event.key === Qt.Key_Up)    { if (playerY > 0) newY--; }
                if (event.key === Qt.Key_S || event.key === Qt.Key_Down)  { if (playerY < 9) newY++; }
                if (event.key === Qt.Key_A || event.key === Qt.Key_Left)  { if (playerX > 0) newX--; }
                if (event.key === Qt.Key_D || event.key === Qt.Key_Right) { if (playerX < 9) newX++; }
                if (newX !== playerX || newY !== playerY) {
                    console.log("Sending move: x =", newX, "y =", newY)
                    gameClient.sendMove(newX, newY) // 只发送请求，不直接修改
                }
                event.accepted = true
            }
        }

        // 新增：其他玩家显示
        Repeater {
            model: otherPlayers
            Rectangle {
                x: modelData.x * 50 + 15
                y: modelData.y * 50 + 15
                width: 20; height: 20
                color: "red" // 可以根据索引动态颜色，例如 color: Qt.rgba(Math.random(), Math.random(), Math.random(), 1)
                radius: 10
            }
        }

        Text {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 20
            text: "Score: " + score
            color: "red"
            font.pixelSize: 30
            z: 10
            onTextChanged: console.log("Score Text changed to:", text)
        }

        // 新增：分数排行榜（显示所有玩家分数）
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 20
            width: 150
            height: 100 + otherPlayers.length * 20 // 动态高度
            color: "white"
            opacity: 0.8
            z: 10

            Column {
                anchors.fill: parent
                spacing: 5
                Text {
                    text: "Leaderboard"
                    font.pixelSize: 20
                    color: "black"
                }
                Text {
                    text: "You: " + score
                    font.pixelSize: 16
                    color: "black"
                }
                Repeater {
                    model: otherPlayers
                    Text {
                        text: "Player " + (index + 1) + ": " + modelData.score
                        font.pixelSize: 16
                        color: "black"
                    }
                }
            }
        }
    }

    // 移除本地 checkCollisions 和 bean 生成，依赖服务器
}
