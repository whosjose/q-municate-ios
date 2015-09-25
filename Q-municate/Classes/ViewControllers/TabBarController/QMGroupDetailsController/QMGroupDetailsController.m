//
//  QMGroupDetailsController.m
//  Qmunicate
//
//  Created by Igor Alefirenko on 12/06/2014.
//  Copyright (c) 2014 Quickblox. All rights reserved.
//

#import "QMGroupDetailsController.h"
#import "QMAddMembersToGroupController.h"
#import "QMGroupDetailsDataSource.h"
#import "SVProgressHUD.h"
#import "QMImageView.h"
#import "QMImagePicker.h"
#import "QMApi.h"
#import "QMContentService.h"
#import "UIImage+Cropper.h"
#import "REActionSheet.h"

@interface QMGroupDetailsController ()

<UITableViewDelegate, UIActionSheetDelegate>

@property (weak, nonatomic) IBOutlet QMImageView *groupAvatarView;
@property (weak, nonatomic) IBOutlet UITextField *groupNameField;
@property (weak, nonatomic) IBOutlet UILabel *occupantsCountLabel;
@property (weak, nonatomic) IBOutlet UILabel *onlineOccupantsCountLabel;
@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (strong, nonatomic) QMGroupDetailsDataSource *dataSource;

@end

@implementation QMGroupDetailsController

- (void)dealloc {
    
    ILog(@"%@ - %@",  NSStringFromSelector(_cmd), self);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(changeGroupAvatar:)];
    [self.groupAvatarView addGestureRecognizer:tap];
    self.groupAvatarView.layer.cornerRadius = self.groupAvatarView.frame.size.width / 2;
    self.groupAvatarView.layer.masksToBounds = YES;
    
    [self updateGUIWithChatDialog:self.chatDialog];
    
    self.dataSource = [[QMGroupDetailsDataSource alloc] initWithTableView:self.tableView];
    [self.dataSource reloadDataWithChatDialog:self.chatDialog];
}


- (void)updateOnlineStatus:(NSUInteger)online {
    
    NSString *onlineUsersCountText = [NSString stringWithFormat:@"%zd/%zd online", online, self.chatDialog.occupantIDs.count];
    self.onlineOccupantsCountLabel.text = onlineUsersCountText;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)viewWillDisappear:(BOOL)animated {
    
    [self.view endEditing:YES];
    [super viewWillDisappear:animated];
}

- (IBAction)changeDialogName:(id)sender {
    
    [SVProgressHUD showWithMaskType:SVProgressHUDMaskTypeClear];
    [[QMApi instance] changeChatName:self.groupNameField.text forChatDialog:self.chatDialog completion:^(QBResponse *response, QBChatDialog *updatedDialog) {
        //
        [SVProgressHUD dismiss];
    }];
}

- (void)changeGroupAvatar:(id)sender {
    
    __weak typeof(self)weakSelf = self;
    [QMImagePicker chooseSourceTypeInVC:self allowsEditing:YES result:^(UIImage *image) {
        
        [SVProgressHUD showWithMaskType:SVProgressHUDMaskTypeClear];
        [[QMApi instance] changeAvatar:image forChatDialog:weakSelf.chatDialog completion:^(QBResponse *response, QBChatDialog *updatedDialog) {
            //
            if (response.success) {
                [weakSelf updateGUIWithChatDialog:updatedDialog];
            }
            [SVProgressHUD dismiss];
        }];
    }];
}

- (IBAction)addFriendsToChat:(id)sender
{
    // check for friends:
    NSArray *friends = [[QMApi instance] contactsOnly];
    NSArray *usersIDs = [[QMApi instance] idsWithUsers:friends];
    NSArray *friendsIDsToAdd = [self filteredIDs:usersIDs forChatDialog:self.chatDialog];
    
    if ([friendsIDsToAdd count] == 0) {
        [[[UIAlertView alloc] initWithTitle:nil
                                    message:NSLocalizedString(@"QM_STR_CANT_ADD_NEW_FRIEND", nil)
                                   delegate:nil
                          cancelButtonTitle:NSLocalizedString(@"QM_STR_CANCEL", nil)
                          otherButtonTitles:nil] show];
        return;
    }
    
    [self performSegueWithIdentifier:kQMAddMembersToGroupControllerSegue sender:nil];
}

- (void)updateGUIWithChatDialog:(QBChatDialog *)chatDialog {
    
    NSAssert(self.chatDialog && chatDialog.type == QBChatDialogTypeGroup , @"Need update this case");

    self.groupNameField.text = chatDialog.name;
    if (chatDialog.photo) {
        [self.groupAvatarView setImageWithURL:[NSURL URLWithString:chatDialog.photo] placeholder:[UIImage imageNamed:@"upic_placeholder_details_group"] options:SDWebImageHighPriority progress:^(NSInteger receivedSize, NSInteger expectedSize) {} completedBlock:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {}];
    }
    self.occupantsCountLabel.text = [NSString stringWithFormat:@"%zd participants", self.chatDialog.occupantIDs.count];
    self.onlineOccupantsCountLabel.text = [NSString stringWithFormat:@"0/%zd online", self.chatDialog.occupantIDs.count];
    

    [self.dataSource reloadDataWithChatDialog:self.chatDialog];
    
    QBChatRoom *chatRoom = self.chatDialog.chatRoom;
    [chatRoom requestOnlineUsers];
}

- (NSArray *)filteredIDs:(NSArray *)IDs forChatDialog:(QBChatDialog *)chatDialog
{
    NSMutableArray *newArray = [[NSMutableArray alloc] initWithArray:IDs];
    [newArray removeObjectsInArray:chatDialog.occupantIDs];
    return [newArray copy];
}


- (void)leaveGroupChat
{
    __weak typeof(self)weakSelf = self;
    [SVProgressHUD show];
    [[QMApi instance] leaveChatDialog:self.chatDialog completion:^(QBResponse *response, QBChatDialog *updatedDialog) {
        //
        [SVProgressHUD dismiss];
        if (response.success) {
            [weakSelf.navigationController popToRootViewControllerAnimated:YES];
        }
    }];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 1) {
        __weak typeof(self)weakSelf = self;
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        [REActionSheet presentActionSheetInView:tableView configuration:^(REActionSheet *actionSheet) {
            actionSheet.title = @"Are you sure?";
            [actionSheet addCancelButtonWihtTitle:@"Cancel" andActionBlock:^{}];
            [actionSheet addDestructiveButtonWithTitle:@"Leave chat" andActionBlock:^{
                // leave logic:
                [weakSelf leaveGroupChat];
            }];
        }];
    }
}

#pragma mark - Segue

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
    if ([segue.identifier isEqualToString:kQMAddMembersToGroupControllerSegue]) {
        QMAddMembersToGroupController *addMembersVC = segue.destinationViewController;
        addMembersVC.chatDialog = self.chatDialog;
    }
}

@end
