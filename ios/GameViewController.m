#import "GameViewController.h"

@implementation GameViewController
- (void)onErrorOnGameUpdate:(NSError *)error {
    [self suspendGame];
    NSLog(@"Dark Magic: %@", error);
    UILabel *label = [[UILabel alloc] init];
    label.text = [NSString stringWithFormat:@"Dark Magic stopped.\n\n%@", error.localizedDescription];
    label.textColor = UIColor.whiteColor;
    label.backgroundColor = UIColor.blackColor;
    label.numberOfLines = 0;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:24],
        [label.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-24],
        [label.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];
}
@end
