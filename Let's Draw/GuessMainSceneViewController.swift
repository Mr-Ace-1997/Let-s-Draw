//
//  GuessMainSceneViewController.swift
//  Let's Draw
//
//  Created by apple on 2017/11/25.
//  Copyright © 2017年 apple. All rights reserved.
//

import UIKit
import os.log
import Alamofire
import Starscream

class GuessMainSceneViewController: UIViewController, UITextFieldDelegate, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, WebSocketDelegate {
    

    //MARK: Properties
    @IBOutlet weak var chattingInputBoxTextField: UITextField!
    @IBOutlet weak var chattingDisplayAreaTextView: UITextView!
    @IBOutlet weak var answerButton: UIButton!
    @IBOutlet weak var renderingBoardArea: RenderingBoard!
    @IBOutlet weak var playerList: UICollectionView!
    
    var hint: String!
    var keyWord: String!
    var me: User?
    var players: [User]!
    
    var socket: WebSocket!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // navigation bar
        navigationItem.title = "提示：" + hint!
        
        // chatting area
        chattingInputBoxTextField.delegate = self
        chattingDisplayAreaTextView.text.append("在这里讨论吧\n")
        chattingDisplayAreaTextView.layoutManager.allowsNonContiguousLayout = false
        
        // answer button
        answerButton.layer.cornerRadius = 5 //  设置为圆角按钮
        
        // player list
        playerList.delegate = self
        playerList.dataSource = self
        let playerListLayout = UICollectionViewFlowLayout.init()
        playerListLayout.itemSize = CGSize(width: 50, height: 70)
        playerListLayout.minimumInteritemSpacing = 10
        playerListLayout.minimumLineSpacing = 10
        playerList.collectionViewLayout = playerListLayout
        
        
        
        // 设置键盘出现时页面上移
        NotificationCenter.default.addObserver(self, selector: #selector(self.kbFrameChanged(_:)), name: .UIKeyboardWillChangeFrame, object: nil)
    }

    // 设置键盘出现时页面上移
    @objc private func kbFrameChanged(_ notification : Notification){
        let info = notification.userInfo
        let kbRect = (info?[UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        let offsetY = kbRect.origin.y - UIScreen.main.bounds.height
        UIView.animate(withDuration: 0.3) {
            self.view.transform = CGAffineTransform(translationX: 0, y: offsetY)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        // web socket
        socket.delegate = self
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    //MARK: UITextFieldDelegate
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let newChattingRecord = textField.text {
            ChattingAreaDelegator.sendChattingMessage(message: newChattingRecord, socket: self.socket, sender: self.me!)
        }
        // text field归还FirstResponser地位
        // Hide the keyboard.
        textField.resignFirstResponder()
        textField.text = ""
        return true
    }
    
    //MARK: UICollectionViewDataSource
    
    //func cel
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return players.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cellIdentifier = "PlayerListCollectionViewCellInGuessScene"
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath) as? PlayerListCellInGuessScene else {
            fatalError("The dequeued cell is not an instance of PlayerListCollectionViewCell.")
        }
        
        let playerInfo = players[indexPath.row]
        cell.updateView(with: playerInfo)
        
        return cell
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    
    //MARK: Actions
    @IBAction func sendMessageBtnPressed(_ sender: UIButton) {
        if let newChattingRecord = chattingInputBoxTextField.text {
            ChattingAreaDelegator.sendChattingMessage(message: newChattingRecord, socket: self.socket, sender: self.me!)
            chattingInputBoxTextField.text = ""
        }
    }
    
    @IBAction func answerButtonPressed(_ sender: UIButton) {
        // 按下回答按钮后，弹出一个对话框用于输入答案
        let answerAlertController = UIAlertController(title: "回答", message: "", preferredStyle: UIAlertControllerStyle.alert)
        answerAlertController.addTextField{
            (textField:UITextField) -> Void in
                textField.placeholder = "请输入你的答案"
        }
        let cancelAction = UIAlertAction(title: "取消", style: UIAlertActionStyle.cancel, handler: nil)
        let confirmAction = UIAlertAction(title: "确定", style: UIAlertActionStyle.default){
            (UIAlertAction) in
                // 提交答案
            if let answer = (answerAlertController.textFields!.first as UITextField?)?.text
            {
                print("[GuessMainScene]Confirm answer:\(answer).")
                self.sendAnswer(content: answer)
            }
        }
        answerAlertController.addAction(cancelAction)
        answerAlertController.addAction(confirmAction)
        self.present(answerAlertController, animated: true, completion: nil)
    }
    
    private func sendAnswer(content answer: String) {
        let parameters:[String: Any] = [
            "type": "sendAnswer",
            "roomId": self.me!.roomId!,
            "playerId": self.me!.id,
            "content": answer,
            "isCorrect": answer == self.keyWord
        ]
        let data = try? JSONSerialization.data(withJSONObject: parameters, options: [])
        socket.write(data: data!)
        
    }
    
    @IBAction func exitbuttonPressed(_ sender: UIBarButtonItem) {
        // 按下退出房间按钮后，弹出对话框询问是否确认退出
        let exitGameRoomAlertController = UIAlertController(title: "退出房间", message: "确定要退出吗？", preferredStyle: UIAlertControllerStyle.alert)
        let cancelAction = UIAlertAction(title: "再玩一会儿", style: UIAlertActionStyle.cancel, handler: nil)
        let confirmAction = UIAlertAction(title: "确定", style: UIAlertActionStyle.default){
            [unowned self] (UIAlertAction) in
            self.exitGameRoom(roomId: self.me!.roomId!)
            self.performSegue(withIdentifier: "unwindToChoosingGameRoomScene", sender: self)
        }
        exitGameRoomAlertController.addAction(cancelAction)
        exitGameRoomAlertController.addAction(confirmAction)
        self.present(exitGameRoomAlertController, animated: true, completion: nil)
        
        
    }
    
    // MARK: Private Methods
    
    private func exitGameRoom(roomId: Int) {
        
        // Connect the server
        let urlPath: String = "http://localhost:3000/tasks/removePlayerFromRoom?roomId=\(roomId)&playerId=\(self.me?.id ?? -1)"
        let params = NSMutableDictionary()
        
        var jsonData:Data? = nil
        do {
            jsonData  = try JSONSerialization.data(withJSONObject: params, options:JSONSerialization.WritingOptions.prettyPrinted)
        } catch {
            fatalError("Wrong post params when trying to creat game room.")
        }
        
        // Use semaphore to send Synchronous request
        let semaphore = DispatchSemaphore(value: 0)
        
        ServerConnectionDelegator.httpPut(urlPath: urlPath, httpBody: jsonData!) {
            (data, error) -> Void in
            if error != nil {
                print(error!)
            } else {
                if let ok = (data as! [NSDictionary])[0]["ok"] {
                    print("removePlayer: ok : \(ok)")
                } else {
                    os_log("removePlayer: unexpected response from server.", log: OSLog.default, type: .debug)
                }
            }
            semaphore.signal()
        }
        
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        
        // socket
        let parameters:[String: Any] = [
            "type": "exitGameRoom",
            "roomId": roomId,
            "playerId": self.me!.id
        ]
        let data = try? JSONSerialization.data(withJSONObject: parameters, options: [])
        socket.write(data: data!)
        
        me!.roomId = -1
    }
    
    
    private func findPlayer(withId id: Int) -> User? {
        for player in players {
            if player.id == id {
                return player
            }
        }
        return nil
    }
    
    // MARK: - WebSocketDelegate
    
    func websocketDidConnect(socket: WebSocketClient) {
        
    }
    
    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        
    }
    
    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        // 1
        guard let data = text.data(using: .utf16),
            let jsonData = try? JSONSerialization.jsonObject(with: data),
            let jsonDict = jsonData as? [String: Any],
            let messageType = jsonDict["type"] as? String
            else {
                return
        }
        
        // 2
        switch messageType {
        case "exitGameRoom":
            if let removedPlayerId = jsonDict["playerId"] as? Int {
                let updatedPlayers = players.filter{ $0.id != removedPlayerId }
                players = updatedPlayers
                self.playerList.reloadData()
            }
        case "chattingMessage":
            if let messageText = jsonDict["messageContent"] as? String, let messageSenderName = jsonDict["playerName"] as? String{
                
                self.chattingDisplayAreaTextView.text.append("\(messageSenderName): \(messageText)\n")
                let allStrCount = self.chattingDisplayAreaTextView.text.count //获取总文字个数
                self.chattingDisplayAreaTextView.scrollRangeToVisible(NSMakeRange(0, allStrCount))//把光标位置移到最后
                //print("webSocket receive message \(messageText)")
            }
        case "sendAnswer":
            if let senderId = jsonDict["playerId"] as? Int,
                let sender = findPlayer(withId: senderId),
                let isAnswerCorrect = jsonDict["isCorrect"] as? Bool,
                let answerContent = jsonDict["content"] as? String
            {
                sender.isAnswerCorrect = isAnswerCorrect
                sender.answerContent = answerContent
                self.playerList.reloadData()
            }
        case "sendDrawingBoard":
            // 画笔颜色
            if let colorName = jsonDict["brushColor"] as? String, let color = DrawingTools.drawingColors[colorName] {
                self.renderingBoardArea.strokeColor = color
            } else {
                os_log("Failed to get brush color.", log: OSLog.default, type: .debug)
            }
            // 画笔种类
            if let brushName = jsonDict["brushKind"] as? String {
                self.renderingBoardArea.brush = DrawingTools.brushes[brushName]
                if brushName == "Eraser" {
                    self.renderingBoardArea.strokeWidth = 15
                } else {
                    self.renderingBoardArea.strokeWidth = 1
                }
            } else {
                os_log("Failed to get brush name.", log: OSLog.default, type: .debug)
            }
            
            // 画
            if let brushState = jsonDict["brushState"] as? String, let x = jsonDict["brushPositionX"] as? CGFloat, let y = jsonDict["brushPositionY"] as? CGFloat {
                switch  brushState{
                case "Began":
                    self.renderingBoardArea.drawWhenTouchBegins(x: x, y: y)
                case "Moved":
                    self.renderingBoardArea.drawWhenTouchMoves(x: x, y: y)
                case "Ended":
                    //print("ended brush state.")
                    self.renderingBoardArea.drawWhenTouchEnds(x: x, y: y)
                default:
                    print("Unknown brush state.")
                }
            } else {
                os_log("Failed to get brush state or position.", log: OSLog.default, type: .debug)
            }
        case "changeGameState":
            if let newGameState = jsonDict["newGameState"] as? String {
                switch newGameState {
                    /*
                     0: ended
                     1: readyToBegin
                     2: onGoing
                     */
                case "ended":
                    // 游戏被结束后，弹出对话框公布正确答案
                    let endGameAlertController = UIAlertController(title: "本局游戏已经结束", message: "正确答案是： \(self.keyWord!)", preferredStyle: UIAlertControllerStyle.alert)
                    let confirmAction = UIAlertAction(title: "确定", style: UIAlertActionStyle.default){
                        (UIAlertAction) in
                        self.performSegue(withIdentifier: "unwindToPrepareScene", sender: self)
                    }
                    endGameAlertController.addAction(confirmAction)
                    self.present(endGameAlertController, animated: true, completion: nil)
                    
                    //print("game is ended")
                default:
                    print("newGameState should be \(newGameState)")
                }
            }
        default:
            os_log("Unknown message type.", log: OSLog.default, type: .debug)
        }
    }
    
    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        
    }
}
