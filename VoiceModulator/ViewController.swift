//
//  ViewController.swift
//  VoiceModulator
//
//  Created by Yejin Hong on 2021/08/11.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, AVAudioRecorderDelegate {
    
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var recordLabel: UILabel!
    @IBOutlet weak var modulButton: UIButton!
    @IBOutlet weak var modulLabel: UILabel!
    @IBOutlet weak var echoButton: UIButton!
    @IBOutlet weak var echoLabel: UILabel!
    @IBOutlet weak var speedButton: UIButton!
    @IBOutlet weak var speedLabel: UILabel!
    @IBOutlet weak var pitchVal: UITextField!
    @IBOutlet weak var speedVal: UITextField!
    @IBOutlet weak var echoVal: UITextField!
    @IBOutlet weak var combButton: UIButton!
    
    var recordedAudioURL: URL!
    var audioFile: AVAudioFile!
    var audioEngine: AVAudioEngine!
    var audioPlayerNode: AVAudioPlayerNode!
    var stopTimer: Timer!
    var audioRecorder: AVAudioRecorder!
    var isRecording: Bool = false
    var isPlaying: Bool = false
    var pit: Float = 0
    var fas: Float = 1
    var ech: Float = 0
    
    enum PlayingState { case playing, notPlaying }
    
    enum ButtonType: Int {
        case lowPitch = 0, echo, fast
    }
    
    struct defaultVal {
        var pitch: Float = 0
        var echo: Float = 0
        var fast: Float = 1
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        modulButton.isEnabled = false
        modulLabel.isEnabled = false
        echoButton.isEnabled = false
        echoLabel.isEnabled = false
        speedButton.isEnabled = false
        speedLabel.isEnabled = false
        pitchVal.isEnabled = false
        speedVal.isEnabled = false
        echoVal.isEnabled = false
        combButton.isEnabled = false
        
        //to dismissKeyboard
        let tap = UITapGestureRecognizer(target: self, action: #selector(UIInputViewController.dismissKeyboard))
        view.addGestureRecognizer(tap)
    }
    
    @IBAction func recordButton(_ sender: Any) {
        if !isRecording {
            let dirPath = NSSearchPathForDirectoriesInDomains(.documentDirectory,.userDomainMask, true)[0] as String
            let recordingName = "recordedVoice.wav"
            let pathArray = [dirPath, recordingName]
            let filePath = URL(string: pathArray.joined(separator: "/"))
            
            //to activate audio session
            let audioSession = AVAudioSession.sharedInstance()
            try! audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: .defaultToSpeaker)
            
            try! audioRecorder = AVAudioRecorder(url: filePath!, settings: [:])
            audioRecorder.delegate = self
            audioRecorder.isMeteringEnabled = true
            audioRecorder.prepareToRecord()
            audioRecorder.record()
            isRecording = true
            recordButton.setImage(UIImage(named: "Stop.png"), for: .normal)
        } else {
            audioRecorder.stop()
            isRecording = false
            recordButton.setImage(UIImage(named: "Record.png"), for: .normal)
            let audioSession = AVAudioSession.sharedInstance()
            try! audioSession.setActive(false)
        }
    }
    
    //called autometically
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            recordedAudioURL = audioRecorder.url
            setupAudio(url: recordedAudioURL)
            
            modulButton.isEnabled = true
            modulLabel.isEnabled = true
            echoButton.isEnabled = true
            echoLabel.isEnabled = true
            speedButton.isEnabled = true
            speedLabel.isEnabled = true
            pitchVal.isEnabled = true
            speedVal.isEnabled = true
            echoVal.isEnabled = true
            combButton.isEnabled = true
            recordButton.isEnabled = false
            recordLabel.isEnabled = false
        } else {
            print("recording was nor succesful")
        }
    }
    
    func setupAudio(url: URL){
        do {
            audioFile = try AVAudioFile(forReading: url)
        } catch {
            print("setupAudio Error")
        }
    }
    
    @IBAction func playButton(_ sender: UIButton) {
        switch(ButtonType(rawValue: sender.tag)!){
        case .lowPitch:
            let val = (pitchVal.text! as NSString).floatValue
            let pitch: Float = val
            pit = pitch
        case .fast:
            let val = (speedVal.text! as NSString).floatValue == 0 ? 1 : (speedVal.text! as NSString).floatValue
            let rate: Float = val
            fas = rate
        case .echo:
            let echo = (echoVal.text! as NSString).floatValue
            ech = echo
        }
    }
    
    @IBAction func combButton(_ sender: Any) {
        print("rate = \(fas), pitch = \(pit), echo = \(ech)")
        playSound(rate: fas, pitch: pit, echo: ech)
    }
    
    func playSound(rate: Float? = nil, pitch: Float? = nil, echo: Float = 0, reverb: Bool = false){
        audioEngine = AVAudioEngine()
        audioPlayerNode = AVAudioPlayerNode()
        audioEngine.attach(audioPlayerNode)
        
        //node for adjusting rate/pitch
        let changeRatePitchNode = AVAudioUnitTimePitch()
        if let pitch = pitch {
            changeRatePitchNode.pitch = pitch
        }
        if let rate = rate {
            changeRatePitchNode.rate = rate
        }
        audioEngine.attach(changeRatePitchNode)
        
        //to set echo
        let echoNode = AVAudioUnitDistortion()
        echoNode.loadFactoryPreset(.multiEcho1)
        echoNode.wetDryMix = echo
        audioEngine.attach(echoNode)
        
        if echo != 0 {
            connectAudioNodes(audioPlayerNode, changeRatePitchNode, echoNode, audioEngine.outputNode)
        } else {
            connectAudioNodes(audioPlayerNode, changeRatePitchNode, audioEngine.outputNode)
        }
        
        audioPlayerNode.stop()
        audioPlayerNode.scheduleFile(audioFile, at: nil) {
            var delayInSeconds: Double = 0
            
            if let lastRenderTime = self.audioPlayerNode.lastRenderTime, let playerTime = self.audioPlayerNode.playerTime(forNodeTime: lastRenderTime) {
                
                if let rate = rate {
                    delayInSeconds = Double(self.audioFile.length - playerTime.sampleTime) / Double(self.audioFile.processingFormat.sampleRate) / Double(rate)
                } else {
                    delayInSeconds = Double(self.audioFile.length - playerTime.sampleTime) / Double(self.audioFile.processingFormat.sampleRate)
                }
            }
            
            self.stopTimer = Timer(timeInterval: delayInSeconds, target: self, selector: #selector(ViewController.stopAudio), userInfo: nil, repeats: false)
            RunLoop.main.add(self.stopTimer!, forMode: RunLoop.Mode.default)
        }
        
        do {
            try audioEngine.start()
        } catch {
            print("error occurs!")
            return
        }
        audioPlayerNode.play()
    }
    
    func configureUI(_ playState: PlayingState) {
        switch(playState) {
        case .playing:
            recordButton.setImage(UIImage(named: "Stop.png"), for: .normal)
        case .notPlaying:
            recordButton.setImage(UIImage(named: "Record.png"), for: .normal)
        }
    }
    
    @objc func stopAudio() {
        
        if let audioPlayerNode = audioPlayerNode {
            audioPlayerNode.stop()
        }
        
        if let stopTimer = stopTimer {
            stopTimer.invalidate()
        }
        
        configureUI(.notPlaying)
        
        if let audioEngine = audioEngine {
            audioEngine.stop()
            audioEngine.reset()
        }
    }
    
    func connectAudioNodes(_ nodes: AVAudioNode...) {
        for x in 0..<nodes.count-1 {
            audioEngine.connect(nodes[x], to: nodes[x+1], format: audioFile.processingFormat)
        }
    }
        @objc func dismissKeyboard() {
            view.endEditing(true)
        }
}

