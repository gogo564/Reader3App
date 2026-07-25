import UIKit

class DZMReadHomeViewCell: UITableViewCell {
    static let ID = "DZMReadHomeViewCell"
    var homeView: DZMReadHomeView!

    class func cell(_ tableView: UITableView) -> DZMReadHomeViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: ID) as? DZMReadHomeViewCell
        if cell == nil {
            cell = DZMReadHomeViewCell(style: .default, reuseIdentifier: ID)
        }
        return cell!
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        homeView = DZMReadHomeView()
        contentView.addSubview(homeView)
    }

    required init?(coder: NSCoder) { nil }
}
