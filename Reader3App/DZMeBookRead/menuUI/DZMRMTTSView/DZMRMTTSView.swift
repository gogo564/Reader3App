import UIKit
import AVFoundation

let DZM_READ_MENU_TTS_VIEW_HEIGHT: CGFloat = 220
let DZM_READ_MENU_TTS_VIEW_TOTAL_HEIGHT: CGFloat = SA(isX: DZM_READ_MENU_TTS_VIEW_HEIGHT + DZM_SPACE_SA_20, DZM_READ_MENU_TTS_VIEW_HEIGHT)

@objc protocol DZMRMTTSViewDelegate: NSObjectProtocol {
    @objc optional func ttsViewDidTapClose(_ ttsView: DZMRMTTSView)
    @objc optional func ttsViewDidTapPlayPause(_ ttsView: DZMRMTTSView)
    @objc optional func ttsViewDidTapPrevious(_ ttsView: DZMRMTTSView)
    @objc optional func ttsViewDidTapNext(_ ttsView: DZMRMTTSView)
    @objc optional func ttsView(_ ttsView: DZMRMTTSView, didChangeSpeed speed: Float)
    @objc optional func ttsView(_ ttsView: DZMRMTTSView, didSelectVoice voice: AVSpeechSynthesisVoice)
}

class DZMRMTTSView: DZMRMBaseView {

    weak var ttsDelegate: DZMRMTTSViewDelegate?

    private var titleLabel: UILabel!
    private var closeButton: UIButton!
    private var playPauseButton: UIButton!
    private var previousButton: UIButton!
    private var nextButton: UIButton!
    private var speedSlider: UISlider!
    private var speedLabel: UILabel!
    private var voiceButton: UIButton!
    private var chapterLabel: UILabel!

    var isPlaying: Bool = false {
        didSet {
            let name = isPlaying ? "pause.fill" : "play.fill"
            playPauseButton.setImage(UIImage(systemName: name)?.withRenderingMode(.alwaysTemplate), for: .normal)
        }
    }

    var currentSpeed: Float = 1.0 {
        didSet {
            speedSlider.value = currentSpeed
            speedLabel.text = String(format: "%.1fx", currentSpeed)
        }
    }

    var chapterName: String = "" {
        didSet {
            chapterLabel.text = chapterName
        }
    }

    func setVoiceName(_ name: String) {
        voiceButton.setTitle(name, for: .normal)
    }

    override init(frame: CGRect) { super.init(frame: frame) }

    override func addSubviews() {
        super.addSubviews()

        backgroundColor = DZM_READ_COLOR_MENU_BG_COLOR

        let w = DZM_READ_CONTENT_VIEW_WIDTH
        let margin: CGFloat = DZM_SPACE_SA_15

        titleLabel = UILabel()
        titleLabel.text = "朗读"
        titleLabel.textColor = DZM_READ_COLOR_MENU_COLOR
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        titleLabel.textAlignment = .center
        addSubview(titleLabel)
        titleLabel.frame = CGRect(x: margin, y: DZM_SPACE_SA_3, width: w - margin * 2, height: 24)

        closeButton = UIButton(type: .custom)
        closeButton.setImage(UIImage(systemName: "xmark")?.withRenderingMode(.alwaysTemplate), for: .normal)
        closeButton.tintColor = DZM_READ_COLOR_MENU_COLOR
        closeButton.addTarget(self, action: #selector(clickClose), for: .touchUpInside)
        addSubview(closeButton)
        closeButton.frame = CGRect(x: w - 40, y: DZM_SPACE_SA_3, width: 30, height: 24)

        chapterLabel = UILabel()
        chapterLabel.textColor = DZM_READ_COLOR_MENU_COLOR.withAlphaComponent(0.7)
        chapterLabel.font = .systemFont(ofSize: 12)
        chapterLabel.textAlignment = .center
        chapterLabel.lineBreakMode = .byTruncatingTail
        addSubview(chapterLabel)
        chapterLabel.frame = CGRect(x: margin, y: titleLabel.frame.maxY + 2, width: w - margin * 2, height: 18)

        let btnY = chapterLabel.frame.maxY + 8
        let btnWH: CGFloat = 44

        previousButton = UIButton(type: .custom)
        previousButton.setImage(UIImage(systemName: "backward.fill")?.withRenderingMode(.alwaysTemplate), for: .normal)
        previousButton.tintColor = DZM_READ_COLOR_MENU_COLOR
        previousButton.addTarget(self, action: #selector(clickPrevious), for: .touchUpInside)
        addSubview(previousButton)
        previousButton.frame = CGRect(x: w / 2 - btnWH - 50, y: btnY, width: btnWH, height: btnWH)

        playPauseButton = UIButton(type: .custom)
        playPauseButton.setImage(UIImage(systemName: "play.fill")?.withRenderingMode(.alwaysTemplate), for: .normal)
        playPauseButton.tintColor = DZM_READ_COLOR_MAIN
        playPauseButton.addTarget(self, action: #selector(clickPlayPause), for: .touchUpInside)
        addSubview(playPauseButton)
        playPauseButton.frame = CGRect(x: w / 2 - btnWH / 2, y: btnY, width: btnWH, height: btnWH)

        nextButton = UIButton(type: .custom)
        nextButton.setImage(UIImage(systemName: "forward.fill")?.withRenderingMode(.alwaysTemplate), for: .normal)
        nextButton.tintColor = DZM_READ_COLOR_MENU_COLOR
        nextButton.addTarget(self, action: #selector(clickNext), for: .touchUpInside)
        addSubview(nextButton)
        nextButton.frame = CGRect(x: w / 2 + 50, y: btnY, width: btnWH, height: btnWH)

        let sliderY = playPauseButton.frame.maxY + 12

        speedLabel = UILabel()
        speedLabel.text = "1.0x"
        speedLabel.textColor = DZM_READ_COLOR_MENU_COLOR
        speedLabel.font = .systemFont(ofSize: 13)
        speedLabel.textAlignment = .right
        addSubview(speedLabel)
        speedLabel.frame = CGRect(x: w - 60, y: sliderY, width: 45, height: 20)

        let speedTitle = UILabel()
        speedTitle.text = "语速"
        speedTitle.textColor = DZM_READ_COLOR_MENU_COLOR
        speedTitle.font = .systemFont(ofSize: 13)
        speedTitle.textAlignment = .left
        addSubview(speedTitle)
        speedTitle.frame = CGRect(x: margin, y: sliderY, width: 35, height: 20)

        speedSlider = UISlider()
        speedSlider.minimumValue = 0.5
        speedSlider.maximumValue = 2.0
        speedSlider.value = 1.0
        speedSlider.minimumTrackTintColor = DZM_READ_COLOR_MAIN
        speedSlider.maximumTrackTintColor = DZM_READ_COLOR_MENU_COLOR.withAlphaComponent(0.3)
        speedSlider.addTarget(self, action: #selector(speedChanged(_:)), for: .valueChanged)
        addSubview(speedSlider)
        speedSlider.frame = CGRect(x: speedTitle.frame.maxX + 6, y: sliderY, width: speedLabel.frame.minX - speedTitle.frame.maxX - 12, height: 20)

        voiceButton = UIButton(type: .custom)
        voiceButton.setTitle("选择语音", for: .normal)
        voiceButton.setTitleColor(DZM_READ_COLOR_MENU_COLOR, for: .normal)
        voiceButton.titleLabel?.font = .systemFont(ofSize: 13)
        voiceButton.contentHorizontalAlignment = .left
        voiceButton.addTarget(self, action: #selector(clickVoice), for: .touchUpInside)
        addSubview(voiceButton)
        voiceButton.frame = CGRect(x: margin, y: speedSlider.frame.maxY + 8, width: w - margin * 2, height: 28)

        let arrow = UIImageView(image: UIImage(systemName: "chevron.right")?.withRenderingMode(.alwaysTemplate))
        arrow.tintColor = DZM_READ_COLOR_MENU_COLOR.withAlphaComponent(0.5)
        arrow.contentMode = .center
        voiceButton.addSubview(arrow)
        arrow.frame = CGRect(x: voiceButton.frame.width - 20, y: 0, width: 14, height: 28)
    }

    @objc private func clickClose() {
        ttsDelegate?.ttsViewDidTapClose?(self)
    }

    @objc private func clickPlayPause() {
        ttsDelegate?.ttsViewDidTapPlayPause?(self)
    }

    @objc private func clickPrevious() {
        ttsDelegate?.ttsViewDidTapPrevious?(self)
    }

    @objc private func clickNext() {
        ttsDelegate?.ttsViewDidTapNext?(self)
    }

    @objc private func speedChanged(_ sender: UISlider) {
        let speed = round(sender.value * 10) / 10
        speedLabel.text = String(format: "%.1fx", speed)
        ttsDelegate?.ttsView?(self, didChangeSpeed: speed)
    }

    @objc private func clickVoice() {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("zh") }
        guard !voices.isEmpty else { return }

        let alert = UIAlertController(title: "选择语音", message: nil, preferredStyle: .actionSheet)
        for v in voices {
            let name = "\(v.name) (\(v.language))"
            alert.addAction(UIAlertAction(title: name, style: .default, handler: { [weak self] _ in
                guard let self = self else { return }
                self.ttsDelegate?.ttsView?(self, didSelectVoice: v)
                self.voiceButton.setTitle(v.name, for: .normal)
            }))
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))

        readMenu?.vc.present(alert, animated: true)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
