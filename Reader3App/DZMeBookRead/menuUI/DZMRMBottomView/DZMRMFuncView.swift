import UIKit

class DZMRMFuncView: DZMRMBaseView {

    private var catalogue:UIButton!
    private var switchSource:UIButton!
    private var dn:UIButton!
    private var setting:UIButton!

    override init(frame: CGRect) { super.init(frame: frame) }

    override func addSubviews() {

        super.addSubviews()

        backgroundColor = UIColor.clear

        catalogue = UIButton(type:.custom)
        catalogue.setImage(UIImage(named:"bar_0")?.withRenderingMode(.alwaysTemplate), for: .normal)
        catalogue.addTarget(self, action: #selector(clickCatalogue), for: .touchUpInside)
        catalogue.tintColor = DZM_READ_COLOR_MENU_COLOR
        addSubview(catalogue)

        switchSource = UIButton(type:.custom)
        switchSource.setImage(UIImage(systemName: "arrow.left.arrow.right")?.withRenderingMode(.alwaysTemplate), for: .normal)
        switchSource.addTarget(self, action: #selector(clickSwitchSource), for: .touchUpInside)
        switchSource.tintColor = DZM_READ_COLOR_MENU_COLOR
        addSubview(switchSource)

        dn = UIButton(type:.custom)
        dn.setImage((UIImage(named:"bar_2") ?? UIImage()).withRenderingMode(.alwaysTemplate), for: .normal)
        dn.addTarget(self, action: #selector(clickDN(_:)), for: .touchUpInside)
        dn.tintColor = DZM_READ_COLOR_MENU_COLOR
        dn.isSelected = DZMUserDefaults.bool(DZM_READ_KEY_MODE_DAY_NIGHT)
        addSubview(dn)
        updateDNButton()

        setting = UIButton(type: .custom)
        setting.setImage((UIImage(named:"bar_1") ?? UIImage()).withRenderingMode(.alwaysTemplate), for: .normal)
        setting.addTarget(self, action: #selector(clickSetting), for: .touchUpInside)
        setting.tintColor = DZM_READ_COLOR_MENU_COLOR
        addSubview(setting)
    }

    @objc private func clickCatalogue() {
        readMenu?.delegate?.readMenuClickCatalogue?(readMenu: readMenu)
    }

    @objc private func clickSwitchSource() {
        readMenu?.delegate?.readMenuClickSwitchSource?(readMenu: readMenu)
    }

    @objc private func clickDN(_ button:UIButton) {
        button.isSelected = !button.isSelected
        updateDNButton()
        DZMUserDefaults.setBool(button.isSelected, DZM_READ_KEY_MODE_DAY_NIGHT)
        readMenu?.delegate?.readMenuClickDayAndNight?(readMenu: readMenu)
    }

    @objc private func clickSetting() {
        readMenu.showTopView(isShow: false)
        readMenu.showBottomView(isShow: false)
        readMenu.showSettingView(isShow: true)
    }

    func updateDNButton() {
        if dn.isSelected { dn.tintColor = DZM_READ_COLOR_MAIN
        }else{ dn.tintColor = DZM_READ_COLOR_MENU_COLOR }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let wh = frame.size.height
        let spacing = (frame.size.width - wh * 4) / 5
        catalogue.frame = CGRect(x: spacing, y: DZM_SPACE_SA_3, width: wh, height: wh)
        switchSource.frame = CGRect(x: spacing * 2 + wh, y: DZM_SPACE_SA_3, width: wh, height: wh)
        dn.frame = CGRect(x: spacing * 3 + wh * 2, y: DZM_SPACE_SA_3, width: wh, height: wh)
        setting.frame = CGRect(x: spacing * 4 + wh * 3, y: DZM_SPACE_SA_3, width: wh, height: wh)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
