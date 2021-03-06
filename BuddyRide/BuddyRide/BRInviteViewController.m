//
//  BRInviteViewController.m
//  BuddyRide
//
//  Created by Yoni Tsafir on 14/6/12.
//  Copyright (c) 2012 YoniTsafir. All rights reserved.
//

#import "BRInviteViewController.h"
#import "Facebook.h"
#import "BRUser.h"
#import "StackMob.h"
#import "BRMapViewController.h"

@interface BRInviteViewController()

@property (nonatomic, strong) NSMutableArray *facebookFriendsWithApp;
@property (nonatomic, strong) NSMutableArray *otherFacebookFriends;
@property (nonatomic, strong) NSMutableDictionary *usersById;

@end

@implementation BRInviteViewController

@synthesize tableView = _tableView;
@synthesize loadingBanner = _loadingBanner;
@synthesize facebookFriendsWithApp = _facebookFriendsWithApp;
@synthesize otherFacebookFriends = _otherFacebookFriends;
@synthesize usersById = _usersById;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)viewDidUnload
{
    [self setTableView:nil];
    [self setLoadingBanner:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    self.loadingBanner.hidden = NO;
    [self.facebook requestWithGraphPath:@"me/friends" andDelegate:self];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return @"Friends with app installed";
    } else {
        return @"Other friends";
    }

}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"FacebookFriend";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                            reuseIdentifier:CellIdentifier];

        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    if (indexPath.section == 0) {
        cell.textLabel.text = [[self.facebookFriendsWithApp objectAtIndex:indexPath.row] name];
        NSData *picData = [NSData dataWithContentsOfURL:[NSURL URLWithString:
                           [NSString stringWithFormat:@"http://graph.facebook.com/%@/picture",
                                     [[self.facebookFriendsWithApp objectAtIndex:indexPath.row] id]]]];
        cell.imageView.image = [UIImage imageWithData:picData];
    } else {
        cell.textLabel.text = [[self.otherFacebookFriends objectAtIndex:indexPath.row] name];
    }

    return cell;

}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return self.facebookFriendsWithApp.count;
    } else {
        return self.otherFacebookFriends.count;
    }

}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;

}


- (void)request:(FBRequest *)request didLoad:(id)result {
    NSArray *resultData = [result objectForKey:@"data"];
    self.facebookFriendsWithApp = [NSMutableArray array];
    self.otherFacebookFriends = [NSMutableArray array];
    self.usersById = [NSMutableDictionary dictionaryWithCapacity:[resultData count]];

    [resultData enumerateObjectsUsingBlock:^(id friend, NSUInteger index, BOOL *stop) {
        BRUser *user = [[BRUser alloc] initWithDictionary:friend];
        [self.usersById setObject:user forKey:user.id];

        [self.otherFacebookFriends addObject:user];
    }];

    StackMobQuery *query = [StackMobQuery query];
    [query field:@"username" mustBeOneOf:[self.usersById allKeys]];

    [[StackMob stackmob] get:@"user" withQuery:query andCallback:^(BOOL success, id stackMobResult) {
        for (NSDictionary *stackMobUser in stackMobResult) {
            BRUser *user = [self.usersById objectForKey:[stackMobUser objectForKey:@"username"]];
            [self.otherFacebookFriends removeObject:user];
            [self.facebookFriendsWithApp addObject:user];

            [self.tableView reloadData];
            self.loadingBanner.hidden = YES;
        }

    }];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    BRUser *user;
    if (indexPath.section == 0) {
        user = [self.facebookFriendsWithApp objectAtIndex:indexPath.row];
    } else {
        user = [self.otherFacebookFriends objectAtIndex:indexPath.row];
    }

    NSString *ourId = [[NSUserDefaults standardUserDefaults] objectForKey:@"FBUserID"];
    NSString *ourName = [[NSUserDefaults standardUserDefaults] objectForKey:@"FBName"];

    NSDictionary *rideArgs = [NSDictionary dictionaryWithObjectsAndKeys:user.id, @"driver", ourId, @"passenger",
                                           @"waiting", @"status", nil];

    [[StackMob stackmob]
            post:@"ride" withArguments:rideArgs andCallback:^(BOOL success, id result) {
        // nothing to check
    }];

    [[StackMob stackmob]
            sendPushToUsersWithArguments:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:1],
                                                                                    @"badge",
                                                                                    [NSString stringWithFormat:@"%@ wants you to come and get him!",
                                                                                              ourName],
                                                                                    @"alert", nil]

            withUserIds:[NSArray arrayWithObject:user.id]
            andCallback:^(BOOL success, id result) {
                NSLog(@"sent push! success:%d, result:%@", success, result);
                // TODO:
            }];

    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];

    BRMapViewController *mapView = [[BRMapViewController alloc]
            initWithNibName:@"BRMapViewController" bundle:nil];
    [self.navigationController pushViewController:mapView animated:YES];
}




@end
