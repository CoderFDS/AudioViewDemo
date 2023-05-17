//
//  AudioView.swift
//  demo
//
//  Created by 呵呵哒 on 2023/5/16.
//

import UIKit
import MediaPlayer


//MARK: - AudioView
class AudioView: UIView {

    enum WaitReadyToPlayState {
        case nomal
        case pause
        case play
    }
    
    enum PlayerPlayState {
        case unknow
        case readyToPlay
        case playing
        case buffering
        case failed
        case pause
        case ended
    }
    private let playingInfoCenter = MPNowPlayingInfoCenter.default()//获取锁屏中心
    private var statusObserve: NSKeyValueObservation?
    private var playbackBufferEmptyObserve: NSKeyValueObservation?
    private var sliderTimer: GCDTimer?
    private var bufferTimer: GCDTimer?
    private var waitReadyToPlayState: WaitReadyToPlayState = .nomal
    
    //播放器
    var player: AVPlayer?
    var playerItem: AVPlayerItem? {
        didSet {
            guard playerItem != oldValue else { return }
            if let oldPlayerItem = oldValue {
                NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: oldPlayerItem)
            }
            guard let playerItem = playerItem else { return }
            NotificationCenter.default.addObserver(self, selector: #selector(didPlaybackEnds), name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
            statusObserve = playerItem.observe(\.status, options: [.new]) { [weak self] _, _ in
                self?.observeStatusAction()
            }
        }
    }
    //总时长
    public private(set) var totalDuration: TimeInterval = .zero {
        didSet {
            guard totalDuration != oldValue else { return }
            if totalDuration.isNaN == true {
                totalDurationLabel.text = "00:00"
            } else {
                let time = Int(totalDuration)
                let hours = time / 3600
                let minutes = (time - hours*3600) / 60
                let seconds = time % 60
                totalDurationLabel.text = hours == .zero ? String(format: "%02ld:%02ld", minutes, seconds) : String(format: "%02ld:%02ld:%02ld", hours, minutes, seconds)
            }
            setupLockScreenInfo()
        }
    }
    //播放时长
    public private(set) var currentDuration: TimeInterval = .zero {
        didSet {
            guard currentDuration != oldValue else { return }
            if currentDuration.isNaN == true {
                currentDurationLabel.text = "00:00"
            } else {
                let time = Int(currentDuration)
                let hours = time / 3600
                let minutes = (time - hours*3600) / 60
                let seconds = time % 60
                currentDurationLabel.text = hours == .zero ? String(format: "%02ld:%02ld", minutes, seconds) : String(format: "%02ld:%02ld:%02ld", hours, minutes, seconds)
            }
        }
    }
    //播放状态
    var playState: PlayerPlayState = .unknow {
        didSet {
            guard playState != oldValue else { return }
            print("playState:\(playState)")
            switch playState {
            case .unknow:
                playBtn.isSelected = false
                break
            case .readyToPlay:
                break
            case .playing:
                playBtn.isSelected = true
                break
            case .buffering:
                break
            case .failed:
                break
            case .pause:
                playBtn.isSelected = false
                break
            case .ended:
                playBtn.isSelected = false
                break
            }
        }
    }
    //倍数
    public private(set) var rate: Float = 1.0 {
        didSet {
            guard rate != oldValue else { return }
            play()
        }
    }
    //记录倍数选择的次数
    private var rateNum = 0
    
    
    
    deinit {
        //停止接受远程响应事件
        UIApplication.shared.endReceivingRemoteControlEvents()
        self.resignFirstResponder()
    }
    override var canBecomeFirstResponder: Bool {
        return true
    }
    override init(frame: CGRect) {
        super.init(frame: frame)
        rateNum = 0
        setUI()
        supportBackgroundPlay()
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    //音频名称
    private lazy var titleLab: UILabel = {
        let v = UILabel()
        v.font = UIFont.boldSystemFont(ofSize: 15.0)
        v.textAlignment = .left
        v.textColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
        v.text = "音频名称"
        return v
    }()
    //slider
    private lazy var sliderView: AudioSlider = {
        let v = AudioSlider()
        v.isUserInteractionEnabled = false
        v.maximumValue = 1
        v.minimumValue = 0
        //设置初始值
        v.value = 0
        //设置可连续变化
        v.isContinuous = true
        //滑轮左边颜色，如果设置了左边的图片就不会显示
        v.minimumTrackTintColor = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
        //滑轮右边颜色，如果设置了右边的图片就不会显示
        v.maximumTrackTintColor = UIColor(red: 0.89, green: 0.89, blue: 0.89, alpha: 1)
        //单纯的滑动可以使用此方法，如果添加点击跳转则需要重写touch方法
        //v.addTarget(self, action: #selector(sliderValueChanged(slider:event:)), for: .valueChanged)
        v.delegate = self
        return v
    }()
    //播放时间
    private lazy var currentDurationLabel: UILabel = {
        let v = UILabel()
        v.textColor = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
        v.font = UIFont.systemFont(ofSize: 10.0)
        v.textAlignment = .left
        v.text = "00:00"
        return v
    }()
    //总时间
    private lazy var totalDurationLabel: UILabel = {
        let v = UILabel()
        v.textColor = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
        v.font = UIFont.systemFont(ofSize: 10.0)
        v.textAlignment = .right
        v.text = "00:00"
        return v
    }()
    //播放/暂停按钮
    private lazy var playBtn: UIButton = {
        let v = UIButton(type: .custom)
        v.setImage(UIImage(named: "audio_play"), for: .selected)
        v.setImage(UIImage(named: "audio_pause"), for: .normal)
        v.addTarget(self, action: #selector(playBtnClick(_ :)), for: .touchUpInside)
        return v
    }()
    //后退15秒
    private lazy var backToAudioBtn: UIButton = {
        let v = UIButton(type: .custom)
        v.setImage(UIImage(named: "audio_back"), for: .normal)
        v.addTarget(self, action: #selector(toAudioBtnClick(_ :)), for: .touchUpInside)
        return v
    }()
    //倍数选择
    private lazy var rateBtn: UIButton = {
        let v = UIButton(type: .custom)
        v.setTitle("倍数", for: .normal)
        v.backgroundColor = UIColor(red: 0.89, green: 0.89, blue: 0.89, alpha: 1)
        v.setTitleColor(UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1), for: .normal)
        v.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        v.layer.cornerRadius = 6.0
        v.addTarget(self, action: #selector(toAudioBtnClick(_ :)), for: .touchUpInside)
        return v
    }()
    //前进15秒
    private lazy var goToAudioBtn: UIButton = {
        let v = UIButton(type: .custom)
        v.setImage(UIImage(named: "audio_go"), for: .normal)
        v.addTarget(self, action: #selector(toAudioBtnClick(_ :)), for: .touchUpInside)
        return v
    }()

}

//MARK: - Data
extension AudioView {
    func setData(urlString: String) {
        //加载网络音乐
        if let url = URL(string: urlString) {
            playerItem = AVPlayerItem(asset: .init(url: url))
            player = AVPlayer(playerItem: playerItem)
        }
        //加载本地音乐
        let path = Bundle.main.path(forResource: "音频", ofType: "mp3") ?? ""
        let url = URL(filePath: path)
        playerItem = AVPlayerItem(asset: .init(url: url))
        player = AVPlayer(playerItem: playerItem)
    }
}

//MARK: - UI
private extension AudioView {
    func setUI() {
        self.addSubview(titleLab)
        self.addSubview(sliderView)
        self.addSubview(currentDurationLabel)
        self.addSubview(totalDurationLabel)
        self.addSubview(playBtn)
        self.addSubview(backToAudioBtn)
        self.addSubview(rateBtn)
        self.addSubview(goToAudioBtn)
        
        titleLab.snp.makeConstraints { make in
            make.top.equalTo(10.0)
            make.left.equalTo(15.0)
            make.height.equalTo(21.0)
        }
        sliderView.snp.makeConstraints { make in
            make.top.equalTo(titleLab.snp.bottom).offset(6.0)
            make.left.equalTo(18.0)
            make.right.equalTo(playBtn.snp.left).offset(-13.0)
            make.height.equalTo(4.0)
        }
        currentDurationLabel.snp.makeConstraints { make in
            make.top.equalTo(sliderView.snp.bottom).offset(5.0)
            make.left.equalTo(titleLab.snp.left)
            make.height.equalTo(14.0)
        }
        totalDurationLabel.snp.makeConstraints { make in
            make.centerY.equalTo(currentDurationLabel.snp.centerY)
            make.height.equalTo(currentDurationLabel.snp.height)
            make.right.equalTo(sliderView.snp.right)
        }
        playBtn.snp.makeConstraints { make in
            make.top.equalTo(17.0)
            make.right.equalTo(-15.0)
            make.width.height.equalTo(36.0)
        }
        backToAudioBtn.snp.makeConstraints { make in
            make.top.equalTo(currentDurationLabel.snp.bottom).offset(15.0)
            make.right.equalTo(rateBtn.snp.left).offset(-45.0)
            make.width.height.equalTo(24.0)
        }
        rateBtn.snp.makeConstraints { make in
            make.centerY.equalTo(backToAudioBtn.snp.centerY)
            make.centerX.equalToSuperview()
            make.width.equalTo(65.0)
            make.height.equalTo(30.0)
        }
        goToAudioBtn.snp.makeConstraints { make in
            make.centerY.equalTo(backToAudioBtn.snp.centerY)
            make.width.equalTo(backToAudioBtn.snp.width)
            make.height.equalTo(backToAudioBtn.snp.height)
            make.left.equalTo(rateBtn.snp.right).offset(45.0)
        }
    }
}


//MARK: - AudioSliderDelegate
extension AudioView: AudioSliderDelegate {
    //开始移动
    func paSliderTouchesBegan(slider: AudioSlider, event: UIEvent) {
        pause()
        controlSliderBarValue(slider: slider, event: event)
    }
    //移动中
    func paSliderTouchesMoved(slider: AudioSlider, event: UIEvent) {
        if currentDuration.isNaN || totalDuration.isNaN {
            return
        }
        currentDuration = ceil(totalDuration * TimeInterval(slider.value))
        let dragedCMTime = CMTimeMake(value: Int64(currentDuration), timescale: 1)
        player?.seek(to: dragedCMTime, toleranceBefore: .zero, toleranceAfter: .zero)
        controlSliderBarValue(slider: slider, event: event)
    }
    //移动结束
    func paSliderTouchesEnded(slider: AudioSlider, event: UIEvent) {
        guard let playerItem = playerItem else { return }
        if slider.value == 1 {
            didPlaybackEnds()
        } else if playerItem.isPlaybackLikelyToKeepUp {
            play()
        } else {
            bufferingSomeSecond()
        }
        controlSliderBarValue(slider: slider, event: event)
    }
}


//MARK: - @objc
@objc private extension AudioView {
    //播放按钮点击事件
    func playBtnClick(_ button: UIButton) {
        button.isSelected = !button.isSelected
        if button.isSelected {
            print("播放")
            play()
        } else {
            print("暂停")
            pause()
        }
    }
    //前进后退15秒
    func toAudioBtnClick(_ button: UIButton) {
        if button == backToAudioBtn {
            print("后退15秒")
            currentDuration = currentDuration - 15
            if currentDuration < 0 {
                currentDuration = 0
            }
            let dragedCMTime = CMTimeMake(value: Int64(currentDuration), timescale: 1)
            player?.seek(to: dragedCMTime, toleranceBefore: .zero, toleranceAfter: .zero)
            sliderView.value = Float(currentDuration / totalDuration)
        } else if button == goToAudioBtn {
            print("前进15秒")
            currentDuration = currentDuration + 15
            if (totalDuration - currentDuration) < 0 {
                currentDuration = totalDuration - 2
            }
            let dragedCMTime = CMTimeMake(value: Int64(currentDuration), timescale: 1)
            player?.seek(to: dragedCMTime, toleranceBefore: .zero, toleranceAfter: .zero)
            sliderView.value = Float(currentDuration / totalDuration)
        } else if button == rateBtn {
            rateNum += 1
            if rateNum == 1 {
                rate = 1.5
                rateBtn.setTitle("x\(rate)", for: .normal)
            } else if rateNum == 2 {
                rate = 2.0
                rateBtn.setTitle("x\(rate)", for: .normal)
            } else {
                rateNum = 0
                rate = 1.0
                rateBtn.setTitle("倍数", for: .normal)
            }
        }
    }
}

//MARK: - 通知
@objc private extension AudioView {
    //播放结束通知
    func didPlaybackEnds() {
        currentDuration = 0
        sliderView.value = 0
        playState = .ended
        sliderTimer?.suspend()
        setupLockScreenInfo()
    }
}

//MARK: - 锁屏界面播放显示操作
extension AudioView {
    override func remoteControlReceived(with event: UIEvent?) {
        guard let et = event else {return}
        if et.type == .remoteControl {
            switch et.subtype {
            case .remoteControlTogglePlayPause:
                print ("暂停/播放")
                break
            case .remoteControlPreviousTrack:
                print ("上一首")
                break
            case .remoteControlNextTrack:
                print ("下一首")
                break
            case .remoteControlPlay:
                print ("播放")
                play()
                break
            case .remoteControlPause:
                print ("暂停")
                pause()
                break
            default:
                break
            }
        }
    }
}

//MARK: - 私有方法
private extension AudioView {
    func observeStatusAction() {
        guard let playerItem = playerItem else { return }
        if playerItem.status == .readyToPlay {
            playState = .readyToPlay
            totalDuration = TimeInterval(playerItem.duration.value) / TimeInterval(playerItem.duration.timescale)
            sliderTimer = GCDTimer(interval: 0.1) { [weak self] _ in
                self?.sliderTimerAction()
            }
            sliderTimer?.start()

            playbackBufferEmptyObserve = playerItem.observe(\.isPlaybackBufferEmpty, options: [.new]) { [weak self] _, _ in
                self?.observePlaybackBufferEmptyAction()
            }

            switch waitReadyToPlayState {
            case .nomal:
                break
            case .pause:
                pause()
            case .play:
                play()
            }
        } else if playerItem.status == .failed {
            playState = .failed
        }
    }

    func observePlaybackBufferEmptyAction() {
        guard playerItem?.isPlaybackBufferEmpty ?? false else { return }
        bufferingSomeSecond()
    }
    
    
    func availableDuration() -> TimeInterval? {
        guard let timeRange = playerItem?.loadedTimeRanges.first?.timeRangeValue else { return nil }
        let startSeconds = CMTimeGetSeconds(timeRange.start)
        let durationSeconds = CMTimeGetSeconds(timeRange.duration)
        return .init(startSeconds + durationSeconds)
    }

    func bufferingSomeSecond() {
        guard playerItem?.status == .readyToPlay else { return }
        guard playState != .failed else { return }

        player?.pause()
        sliderTimer?.suspend()
        bufferTimer?.cancel()

        playState = .buffering
        bufferTimer = GCDTimer(interval: 0, delaySecs: 3.0, repeats: false, action: { [weak self] _ in
            guard let playerItem = self?.playerItem else { return }
            if playerItem.isPlaybackLikelyToKeepUp {
                self?.play()
            } else {
                self?.bufferingSomeSecond()
            }
        })
        bufferTimer?.start()
    }

    func sliderTimerAction() {
        guard let playerItem = playerItem else { return }
        guard playerItem.duration.timescale != .zero else { return }

        currentDuration = CMTimeGetSeconds(playerItem.currentTime())
        sliderView.value = Float(currentDuration / totalDuration)
    }
    
    func controlSliderBarValue(slider: AudioSlider, event: UIEvent?) {
        if let allTouches = event?.allTouches as? NSSet, let touch = allTouches.anyObject() as AnyObject? {
            let touchLocation = touch.location(in: slider)
            let value = (slider.maximumValue - slider.minimumValue) * Float(touchLocation.x / slider.frame.width)
            slider.value = value
        }
    }
}

//MARK: - 公有方法
extension AudioView {
    func play() {
        guard let playerItem = playerItem else { return }
        if playState == .failed {
            print("播放失败，请检查资源")
        }
        guard playerItem.status == .readyToPlay else {
            waitReadyToPlayState = .play
            return
        }
        guard playerItem.isPlaybackLikelyToKeepUp else {
            bufferingSomeSecond()
            return
        }
        if playState == .ended {
            player?.seek(to: CMTimeMake(value: 0, timescale: 1), toleranceBefore: .zero, toleranceAfter: .zero)
        }
        playState = .playing
        player?.play()
        player?.rate = rate
        sliderTimer?.resume()
        waitReadyToPlayState = .nomal
        
        setupLockScreenInfo()
    }

    func pause() {
        guard playerItem?.status == .readyToPlay else {
            waitReadyToPlayState = .pause
            return
        }
        playState = .pause
        player?.pause()
        sliderTimer?.suspend()
        bufferTimer?.cancel()
        waitReadyToPlayState = .nomal
    }

    func stop() {
        statusObserve?.invalidate()
        playbackBufferEmptyObserve?.invalidate()

        statusObserve = nil
        playbackBufferEmptyObserve = nil

        playerItem = nil
        player = nil


        waitReadyToPlayState = .nomal

        playState = .unknow
        sliderView.value = 0
        totalDuration = 0
        currentDuration = 0
        sliderTimer?.cancel()
    }
}

//MARK: - 后台播放，锁屏界面设置
private extension AudioView {
    //支持后台播放
    func supportBackgroundPlay() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback)
            try audioSession.setActive(true)
        } catch let err {
            print("后台播放失败：",err.localizedDescription)
        }
        //接受远程响应事件
        UIApplication.shared.beginReceivingRemoteControlEvents()
        self.becomeFirstResponder()
    }
    //音乐锁屏信息展示
    func setupLockScreenInfo() {
        let artwork = MPMediaItemArtwork.init(boundsSize: CGSize(width: 200, height: 200)) { size in
            return UIImage(named: "picture.jpg")!
        }
        playingInfoCenter.nowPlayingInfo = [MPMediaItemPropertyTitle: "歌曲名称",//播放标题
                              MPMediaItemPropertyArtist: "歌手名字",
                             MPMediaItemPropertyArtwork: artwork,//播放封面图
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentDuration,//已经播放时长
                    MPMediaItemPropertyPlaybackDuration: totalDuration,//总时长
                    MPNowPlayingInfoPropertyPlaybackRate: rate,//播放倍数
                       MPNowPlayingInfoPropertyMediaType: 1]//音频类型
        
    }
}

//MARK: - AudioSlider
protocol AudioSliderDelegate: AnyObject {
    func paSliderTouchesBegan(slider: AudioSlider, event: UIEvent)
    func paSliderTouchesMoved(slider: AudioSlider, event: UIEvent)
    func paSliderTouchesEnded(slider: AudioSlider, event: UIEvent)
}
class AudioSlider: UISlider {
    
    weak var delegate: AudioSliderDelegate?
    
    private var lastBounds: CGRect = .zero
    private let sliderBoundX: CGFloat = 30
    private let sliderBoundY: CGFloat = 40
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setThumbImage(UIImage(named: "audio_slider"), for: .normal)
    }
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    //修改滑道的高度
    override func trackRect(forBounds bounds: CGRect) -> CGRect {
        super.trackRect(forBounds: bounds)
        return .init(origin: bounds.origin, size: CGSize(width: bounds.width, height: 4))
    }
    
    //增大滑块的触摸范围
    override func thumbRect(forBounds bounds: CGRect, trackRect rect: CGRect, value: Float) -> CGRect {
        var rect = rect
        rect.origin.x = rect.minX
        rect.size.width = rect.width
        lastBounds = super.thumbRect(forBounds: bounds, trackRect: rect, value: value)
        return lastBounds
    }
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        guard view != self else { return view }
        guard point.x >= 0, point.x < bounds.width else { return view }
        guard point.y >= -15, point.y < lastBounds.height + sliderBoundY else { return view }
        return self
    }
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let result = super.point(inside: point, with: event)
        guard !result else { return result }
        guard point.x >= lastBounds.minX - sliderBoundX, point.x <= lastBounds.maxX + sliderBoundX else { return result }
        guard point.y >= -sliderBoundY, point.y < lastBounds.height + sliderBoundY else { return result }
        return true
    }
    
    //触摸事件
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let e = event {
            delegate?.paSliderTouchesBegan(slider: self, event: e)
        }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let e = event {
            delegate?.paSliderTouchesMoved(slider: self, event: e)
        }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let e = event {
            delegate?.paSliderTouchesEnded(slider: self, event: e)
        }
    }
}

//MARK: - GCDTimer
class GCDTimer: NSObject {
    typealias actionBlock = ((NSInteger) -> Void)
    private var interval: TimeInterval!
    private var delaySecs: TimeInterval!
    private var serialQueue: DispatchQueue!
    private var repeats: Bool = true
    private var action: actionBlock?
    private var timer: DispatchSourceTimer!
    private var isRuning: Bool = false
    private(set) var actionTimes: NSInteger = 0
    
    init(interval: TimeInterval, delaySecs: TimeInterval = 0, queue: DispatchQueue = .main, repeats: Bool = true, action: actionBlock?) {
        super.init()
        self.interval = interval
        self.delaySecs = delaySecs
        self.repeats = repeats
        serialQueue = queue
        self.action = action
        timer = DispatchSource.makeTimerSource(queue: serialQueue)
    }

    /// 替换旧响应
    func replaceOldAction(action: actionBlock?) {
        guard let action = action else {
            return
        }
        self.action = action
    }

    /// 执行一次定时器响应
    func responseOnce() {
        actionTimes += 1
        isRuning = true
        action?(actionTimes)
        isRuning = false
    }

    deinit {
        cancel()
    }
}

extension GCDTimer {
    /// 开始定时器
    func start() {
        timer.schedule(deadline: .now() + delaySecs, repeating: interval)
        timer.setEventHandler { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.actionTimes += 1
            strongSelf.action?(strongSelf.actionTimes)
            if !strongSelf.repeats {
                strongSelf.cancel()
                strongSelf.action = nil
            }
        }
        resume()
    }

    /// 暂停
    func suspend() {
        if isRuning {
            timer.suspend()
            isRuning = false
        }
    }

    /// 恢复定时器
    func resume() {
        if !isRuning {
            timer.resume()
            isRuning = true
        }
    }

    /// 取消定时器
    func cancel() {
        if !isRuning {
            resume()
        }
        timer.cancel()
    }
}
