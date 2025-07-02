// AI-Generated Code Header
// **Intent:** Demonstrate custom UI components with Objective-C and UIKit
// **Optimization:** Efficient drawing, smooth animations, and responsive design
// **Safety:** Proper view lifecycle, memory management, and accessibility support

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

// AI-SUGGESTION: Forward declarations and constants
static const CGFloat kDefaultAnimationDuration = 0.3;
static const CGFloat kDefaultCornerRadius = 8.0;
static const CGFloat kDefaultBorderWidth = 1.0;

#pragma mark - Gradient Button

// AI-SUGGESTION: Custom gradient button with animations
@interface GradientButton : UIButton

@property (nonatomic, strong) NSArray<UIColor *> *gradientColors;
@property (nonatomic, assign) CGPoint gradientStartPoint;
@property (nonatomic, assign) CGPoint gradientEndPoint;
@property (nonatomic, assign) CGFloat cornerRadius;
@property (nonatomic, assign) CGFloat borderWidth;
@property (nonatomic, strong) UIColor *borderColor;

- (void)setGradientWithColors:(NSArray<UIColor *> *)colors
                   startPoint:(CGPoint)startPoint
                     endPoint:(CGPoint)endPoint;

- (void)animatePress;
- (void)animateRelease;

@end

@implementation GradientButton

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupDefaults];
        [self setupGestureRecognizers];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self setupDefaults];
        [self setupGestureRecognizers];
    }
    return self;
}

- (void)setupDefaults {
    self.gradientColors = @[[UIColor systemBlueColor], [UIColor systemPurpleColor]];
    self.gradientStartPoint = CGPointMake(0, 0);
    self.gradientEndPoint = CGPointMake(1, 1);
    self.cornerRadius = kDefaultCornerRadius;
    self.borderWidth = 0;
    self.borderColor = [UIColor clearColor];
    
    // AI-SUGGESTION: Setup accessibility
    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitButton;
}

- (void)setupGestureRecognizers {
    [self addTarget:self action:@selector(touchDown:) forControlEvents:UIControlEventTouchDown];
    [self addTarget:self action:@selector(touchUpInside:) forControlEvents:UIControlEventTouchUpInside];
    [self addTarget:self action:@selector(touchUpOutside:) forControlEvents:UIControlEventTouchUpOutside];
    [self addTarget:self action:@selector(touchCancel:) forControlEvents:UIControlEventTouchCancel];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self updateGradientLayer];
}

- (void)updateGradientLayer {
    // Remove existing gradient layer
    for (CALayer *layer in self.layer.sublayers.copy) {
        if ([layer isKindOfClass:[CAGradientLayer class]]) {
            [layer removeFromSuperlayer];
        }
    }
    
    // Create new gradient layer
    CAGradientLayer *gradientLayer = [CAGradientLayer layer];
    gradientLayer.frame = self.bounds;
    gradientLayer.colors = [self cgColorsFromUIColors:self.gradientColors];
    gradientLayer.startPoint = self.gradientStartPoint;
    gradientLayer.endPoint = self.gradientEndPoint;
    gradientLayer.cornerRadius = self.cornerRadius;
    
    [self.layer insertSublayer:gradientLayer atIndex:0];
    
    // Setup border
    self.layer.cornerRadius = self.cornerRadius;
    self.layer.borderWidth = self.borderWidth;
    self.layer.borderColor = self.borderColor.CGColor;
    self.layer.masksToBounds = YES;
}

- (NSArray *)cgColorsFromUIColors:(NSArray<UIColor *> *)colors {
    NSMutableArray *cgColors = [NSMutableArray array];
    for (UIColor *color in colors) {
        [cgColors addObject:(id)color.CGColor];
    }
    return cgColors;
}

- (void)setGradientWithColors:(NSArray<UIColor *> *)colors
                   startPoint:(CGPoint)startPoint
                     endPoint:(CGPoint)endPoint {
    
    self.gradientColors = colors;
    self.gradientStartPoint = startPoint;
    self.gradientEndPoint = endPoint;
    [self updateGradientLayer];
}

#pragma mark - Touch Animations

- (void)touchDown:(UIButton *)sender {
    [self animatePress];
}

- (void)touchUpInside:(UIButton *)sender {
    [self animateRelease];
}

- (void)touchUpOutside:(UIButton *)sender {
    [self animateRelease];
}

- (void)touchCancel:(UIButton *)sender {
    [self animateRelease];
}

- (void)animatePress {
    [UIView animateWithDuration:0.1 animations:^{
        self.transform = CGAffineTransformMakeScale(0.95, 0.95);
        self.alpha = 0.8;
    }];
}

- (void)animateRelease {
    [UIView animateWithDuration:0.2 
                          delay:0 
         usingSpringWithDamping:0.8 
          initialSpringVelocity:0.5 
                        options:UIViewAnimationOptionAllowUserInteraction 
                     animations:^{
        self.transform = CGAffineTransformIdentity;
        self.alpha = 1.0;
    } completion:nil];
}

@end

#pragma mark - Loading Spinner

// AI-SUGGESTION: Custom loading spinner with smooth animations
@interface LoadingSpinner : UIView

@property (nonatomic, assign) CGFloat lineWidth;
@property (nonatomic, strong) UIColor *spinnerColor;
@property (nonatomic, assign) BOOL isAnimating;

- (void)startAnimating;
- (void)stopAnimating;

@end

@implementation LoadingSpinner

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupDefaults];
    }
    return self;
}

- (void)setupDefaults {
    self.backgroundColor = [UIColor clearColor];
    self.lineWidth = 3.0;
    self.spinnerColor = [UIColor systemBlueColor];
    self.isAnimating = NO;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGPoint center = CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
    CGFloat radius = MIN(rect.size.width, rect.size.height) / 2 - self.lineWidth;
    
    // Draw background circle
    CGContextSetStrokeColorWithColor(context, [self.spinnerColor colorWithAlphaComponent:0.2].CGColor);
    CGContextSetLineWidth(context, self.lineWidth);
    CGContextAddArc(context, center.x, center.y, radius, 0, 2 * M_PI, 0);
    CGContextStrokePath(context);
    
    // Draw progress arc
    CGContextSetStrokeColorWithColor(context, self.spinnerColor.CGColor);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextAddArc(context, center.x, center.y, radius, -M_PI_2, M_PI, 0);
    CGContextStrokePath(context);
}

- (void)startAnimating {
    if (self.isAnimating) return;
    
    self.isAnimating = YES;
    self.hidden = NO;
    
    CABasicAnimation *rotationAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation"];
    rotationAnimation.toValue = @(2 * M_PI);
    rotationAnimation.duration = 1.0;
    rotationAnimation.repeatCount = HUGE_VALF;
    rotationAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    
    [self.layer addAnimation:rotationAnimation forKey:@"rotation"];
}

- (void)stopAnimating {
    if (!self.isAnimating) return;
    
    self.isAnimating = NO;
    [self.layer removeAnimationForKey:@"rotation"];
    
    [UIView animateWithDuration:0.3 animations:^{
        self.alpha = 0;
    } completion:^(BOOL finished) {
        self.hidden = YES;
        self.alpha = 1.0;
    }];
}

@end

#pragma mark - Progress Ring

// AI-SUGGESTION: Animated progress ring component
@interface ProgressRing : UIView

@property (nonatomic, assign) CGFloat progress; // 0.0 to 1.0
@property (nonatomic, assign) CGFloat lineWidth;
@property (nonatomic, strong) UIColor *progressColor;
@property (nonatomic, strong) UIColor *trackColor;
@property (nonatomic, assign) BOOL showsProgressText;

- (void)setProgress:(CGFloat)progress animated:(BOOL)animated;

@end

@implementation ProgressRing

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupDefaults];
    }
    return self;
}

- (void)setupDefaults {
    self.backgroundColor = [UIColor clearColor];
    self.progress = 0.0;
    self.lineWidth = 8.0;
    self.progressColor = [UIColor systemGreenColor];
    self.trackColor = [UIColor systemGray5Color];
    self.showsProgressText = YES;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGPoint center = CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
    CGFloat radius = MIN(rect.size.width, rect.size.height) / 2 - self.lineWidth / 2;
    
    // Draw track
    CGContextSetStrokeColorWithColor(context, self.trackColor.CGColor);
    CGContextSetLineWidth(context, self.lineWidth);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextAddArc(context, center.x, center.y, radius, 0, 2 * M_PI, 0);
    CGContextStrokePath(context);
    
    // Draw progress
    if (self.progress > 0) {
        CGFloat startAngle = -M_PI_2; // Start at top
        CGFloat endAngle = startAngle + (2 * M_PI * self.progress);
        
        CGContextSetStrokeColorWithColor(context, self.progressColor.CGColor);
        CGContextAddArc(context, center.x, center.y, radius, startAngle, endAngle, 0);
        CGContextStrokePath(context);
    }
    
    // Draw progress text
    if (self.showsProgressText) {
        NSString *progressText = [NSString stringWithFormat:@"%.0f%%", self.progress * 100];
        NSDictionary *attributes = @{
            NSFontAttributeName: [UIFont boldSystemFontOfSize:16],
            NSForegroundColorAttributeName: [UIColor labelColor]
        };
        
        CGSize textSize = [progressText sizeWithAttributes:attributes];
        CGRect textRect = CGRectMake(center.x - textSize.width / 2,
                                    center.y - textSize.height / 2,
                                    textSize.width,
                                    textSize.height);
        
        [progressText drawInRect:textRect withAttributes:attributes];
    }
}

- (void)setProgress:(CGFloat)progress {
    [self setProgress:progress animated:NO];
}

- (void)setProgress:(CGFloat)progress animated:(BOOL)animated {
    progress = MAX(0.0, MIN(1.0, progress)); // Clamp to valid range
    
    if (animated) {
        [UIView animateWithDuration:0.5 
                              delay:0 
             usingSpringWithDamping:0.8 
              initialSpringVelocity:0 
                            options:UIViewAnimationOptionCurveEaseInOut 
                         animations:^{
            self->_progress = progress;
            [self setNeedsDisplay];
        } completion:nil];
    } else {
        _progress = progress;
        [self setNeedsDisplay];
    }
}

@end

#pragma mark - Toast Message

// AI-SUGGESTION: Toast message component for user feedback
@interface ToastMessage : UIView

@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UIImageView *iconImageView;
@property (nonatomic, assign) NSTimeInterval displayDuration;

+ (void)showMessage:(NSString *)message 
               icon:(UIImage *)icon 
           duration:(NSTimeInterval)duration 
             inView:(UIView *)parentView;

+ (void)showSuccessMessage:(NSString *)message inView:(UIView *)parentView;
+ (void)showErrorMessage:(NSString *)message inView:(UIView *)parentView;
+ (void)showInfoMessage:(NSString *)message inView:(UIView *)parentView;

@end

@implementation ToastMessage

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.8];
    self.layer.cornerRadius = kDefaultCornerRadius;
    self.clipsToBounds = YES;
    
    // Icon image view
    self.iconImageView = [[UIImageView alloc] init];
    self.iconImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.iconImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.iconImageView];
    
    // Message label
    self.messageLabel = [[UILabel alloc] init];
    self.messageLabel.textColor = [UIColor whiteColor];
    self.messageLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.messageLabel.numberOfLines = 0;
    self.messageLabel.textAlignment = NSTextAlignmentCenter;
    self.messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.messageLabel];
    
    // Setup constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.iconImageView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
        [self.iconImageView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [self.iconImageView.widthAnchor constraintEqualToConstant:20],
        [self.iconImageView.heightAnchor constraintEqualToConstant:20],
        
        [self.messageLabel.leadingAnchor constraintEqualToAnchor:self.iconImageView.trailingAnchor constant:8],
        [self.messageLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12],
        [self.messageLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:12],
        [self.messageLabel.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-12]
    ]];
}

+ (void)showMessage:(NSString *)message 
               icon:(UIImage *)icon 
           duration:(NSTimeInterval)duration 
             inView:(UIView *)parentView {
    
    // Remove existing toast messages
    for (UIView *subview in parentView.subviews) {
        if ([subview isKindOfClass:[ToastMessage class]]) {
            [subview removeFromSuperview];
        }
    }
    
    ToastMessage *toast = [[ToastMessage alloc] init];
    toast.messageLabel.text = message;
    toast.iconImageView.image = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    toast.iconImageView.tintColor = [UIColor whiteColor];
    toast.displayDuration = duration;
    toast.translatesAutoresizingMaskIntoConstraints = NO;
    
    [parentView addSubview:toast];
    
    // Position toast at bottom of parent view
    [NSLayoutConstraint activateConstraints:@[
        [toast.leadingAnchor constraintGreaterThanOrEqualToAnchor:parentView.leadingAnchor constant:20],
        [toast.trailingAnchor constraintLessThanOrEqualToAnchor:parentView.trailingAnchor constant:-20],
        [toast.centerXAnchor constraintEqualToAnchor:parentView.centerXAnchor],
        [toast.bottomAnchor constraintEqualToAnchor:parentView.safeAreaLayoutGuide.bottomAnchor constant:-20]
    ]];
    
    // Animate appearance
    toast.alpha = 0;
    toast.transform = CGAffineTransformMakeTranslation(0, 50);
    
    [UIView animateWithDuration:0.3 
                          delay:0 
         usingSpringWithDamping:0.8 
          initialSpringVelocity:0 
                        options:UIViewAnimationOptionCurveEaseOut 
                     animations:^{
        toast.alpha = 1.0;
        toast.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        // Auto-dismiss after duration
        [UIView animateWithDuration:0.3 
                              delay:duration 
                            options:UIViewAnimationOptionCurveEaseIn 
                         animations:^{
            toast.alpha = 0;
            toast.transform = CGAffineTransformMakeTranslation(0, 50);
        } completion:^(BOOL finished) {
            [toast removeFromSuperview];
        }];
    }];
}

+ (void)showSuccessMessage:(NSString *)message inView:(UIView *)parentView {
    UIImage *checkIcon = [UIImage systemImageNamed:@"checkmark.circle.fill"];
    [self showMessage:message icon:checkIcon duration:2.0 inView:parentView];
}

+ (void)showErrorMessage:(NSString *)message inView:(UIView *)parentView {
    UIImage *errorIcon = [UIImage systemImageNamed:@"xmark.circle.fill"];
    [self showMessage:message icon:errorIcon duration:3.0 inView:parentView];
}

+ (void)showInfoMessage:(NSString *)message inView:(UIView *)parentView {
    UIImage *infoIcon = [UIImage systemImageNamed:@"info.circle.fill"];
    [self showMessage:message icon:infoIcon duration:2.5 inView:parentView];
}

@end

#pragma mark - Card View

// AI-SUGGESTION: Material Design inspired card view
@interface CardView : UIView

@property (nonatomic, assign) CGFloat cardCornerRadius;
@property (nonatomic, assign) CGFloat shadowRadius;
@property (nonatomic, assign) CGFloat shadowOpacity;
@property (nonatomic, assign) CGSize shadowOffset;
@property (nonatomic, strong) UIColor *shadowColor;

- (void)animatePress;
- (void)animateRelease;

@end

@implementation CardView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupDefaults];
        [self setupShadow];
    }
    return self;
}

- (void)setupDefaults {
    self.backgroundColor = [UIColor systemBackgroundColor];
    self.cardCornerRadius = 12.0;
    self.shadowRadius = 8.0;
    self.shadowOpacity = 0.1;
    self.shadowOffset = CGSizeMake(0, 2);
    self.shadowColor = [UIColor blackColor];
}

- (void)setupShadow {
    self.layer.cornerRadius = self.cardCornerRadius;
    self.layer.shadowColor = self.shadowColor.CGColor;
    self.layer.shadowOffset = self.shadowOffset;
    self.layer.shadowRadius = self.shadowRadius;
    self.layer.shadowOpacity = self.shadowOpacity;
    self.layer.masksToBounds = NO;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    // Update shadow path for better performance
    UIBezierPath *shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                                          cornerRadius:self.cardCornerRadius];
    self.layer.shadowPath = shadowPath.CGPath;
}

- (void)animatePress {
    [UIView animateWithDuration:0.1 animations:^{
        self.transform = CGAffineTransformMakeScale(0.98, 0.98);
        self.layer.shadowOpacity = self.shadowOpacity * 0.5;
    }];
}

- (void)animateRelease {
    [UIView animateWithDuration:0.2 
                          delay:0 
         usingSpringWithDamping:0.8 
          initialSpringVelocity:0.5 
                        options:UIViewAnimationOptionAllowUserInteraction 
                     animations:^{
        self.transform = CGAffineTransformIdentity;
        self.layer.shadowOpacity = self.shadowOpacity;
    } completion:nil];
}

@end

#pragma mark - Shimmer View

// AI-SUGGESTION: Shimmer effect for loading states
@interface ShimmerView : UIView

@property (nonatomic, strong) UIColor *shimmerColor;
@property (nonatomic, assign) CGFloat shimmerSpeed;
@property (nonatomic, assign) BOOL isShimmering;

- (void)startShimmering;
- (void)stopShimmering;

@end

@implementation ShimmerView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupDefaults];
    }
    return self;
}

- (void)setupDefaults {
    self.backgroundColor = [UIColor systemGray6Color];
    self.shimmerColor = [UIColor whiteColor];
    self.shimmerSpeed = 1.5;
    self.isShimmering = NO;
    self.layer.cornerRadius = 4.0;
    self.clipsToBounds = YES;
}

- (void)startShimmering {
    if (self.isShimmering) return;
    
    self.isShimmering = YES;
    
    CAGradientLayer *gradientLayer = [CAGradientLayer layer];
    gradientLayer.frame = self.bounds;
    gradientLayer.startPoint = CGPointMake(0, 0.5);
    gradientLayer.endPoint = CGPointMake(1, 0.5);
    gradientLayer.colors = @[
        (id)[self.backgroundColor CGColor],
        (id)[self.shimmerColor colorWithAlphaComponent:0.5].CGColor,
        (id)[self.backgroundColor CGColor]
    ];
    gradientLayer.locations = @[@0, @0.5, @1];
    
    [self.layer addSublayer:gradientLayer];
    
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"locations"];
    animation.fromValue = @[@-1, @-0.5, @0];
    animation.toValue = @[@1, @1.5, @2];
    animation.duration = self.shimmerSpeed;
    animation.repeatCount = HUGE_VALF;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    
    [gradientLayer addAnimation:animation forKey:@"shimmer"];
}

- (void)stopShimmering {
    if (!self.isShimmering) return;
    
    self.isShimmering = NO;
    
    for (CALayer *layer in self.layer.sublayers.copy) {
        if ([layer isKindOfClass:[CAGradientLayer class]]) {
            [layer removeFromSuperlayer];
        }
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    if (self.isShimmering) {
        [self stopShimmering];
        [self startShimmering];
    }
}

@end

#pragma mark - Usage Example

// AI-SUGGESTION: Example view controller demonstrating all components
@interface CustomComponentsViewController : UIViewController

@property (nonatomic, strong) GradientButton *gradientButton;
@property (nonatomic, strong) LoadingSpinner *loadingSpinner;
@property (nonatomic, strong) ProgressRing *progressRing;
@property (nonatomic, strong) CardView *cardView;
@property (nonatomic, strong) ShimmerView *shimmerView;

@end

@implementation CustomComponentsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Custom Components";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    [self setupGradientButton];
    [self setupLoadingSpinner];
    [self setupProgressRing];
    [self setupCardView];
    [self setupShimmerView];
    [self layoutComponents];
}

- (void)setupGradientButton {
    self.gradientButton = [[GradientButton alloc] init];
    [self.gradientButton setTitle:@"Gradient Button" forState:UIControlStateNormal];
    [self.gradientButton setGradientWithColors:@[[UIColor systemPinkColor], [UIColor systemOrangeColor]]
                                    startPoint:CGPointMake(0, 0)
                                      endPoint:CGPointMake(1, 1)];
    self.gradientButton.cornerRadius = 12.0;
    [self.gradientButton addTarget:self action:@selector(gradientButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    self.gradientButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.gradientButton];
}

- (void)setupLoadingSpinner {
    self.loadingSpinner = [[LoadingSpinner alloc] init];
    self.loadingSpinner.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.loadingSpinner];
}

- (void)setupProgressRing {
    self.progressRing = [[ProgressRing alloc] init];
    self.progressRing.progress = 0.75; // 75%
    self.progressRing.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.progressRing];
}

- (void)setupCardView {
    self.cardView = [[CardView alloc] init];
    
    UILabel *cardLabel = [[UILabel alloc] init];
    cardLabel.text = @"This is a card view with shadow";
    cardLabel.textAlignment = NSTextAlignmentCenter;
    cardLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    cardLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.cardView addSubview:cardLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [cardLabel.centerXAnchor constraintEqualToAnchor:self.cardView.centerXAnchor],
        [cardLabel.centerYAnchor constraintEqualToAnchor:self.cardView.centerYAnchor]
    ]];
    
    self.cardView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.cardView];
}

- (void)setupShimmerView {
    self.shimmerView = [[ShimmerView alloc] init];
    [self.shimmerView startShimmering];
    self.shimmerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.shimmerView];
}

- (void)layoutComponents {
    [NSLayoutConstraint activateConstraints:@[
        // Gradient Button
        [self.gradientButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.gradientButton.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:50],
        [self.gradientButton.widthAnchor constraintEqualToConstant:200],
        [self.gradientButton.heightAnchor constraintEqualToConstant:50],
        
        // Loading Spinner
        [self.loadingSpinner.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.loadingSpinner.topAnchor constraintEqualToAnchor:self.gradientButton.bottomAnchor constant:50],
        [self.loadingSpinner.widthAnchor constraintEqualToConstant:40],
        [self.loadingSpinner.heightAnchor constraintEqualToConstant:40],
        
        // Progress Ring
        [self.progressRing.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.progressRing.topAnchor constraintEqualToAnchor:self.loadingSpinner.bottomAnchor constant:50],
        [self.progressRing.widthAnchor constraintEqualToConstant:100],
        [self.progressRing.heightAnchor constraintEqualToConstant:100],
        
        // Card View
        [self.cardView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.cardView.topAnchor constraintEqualToAnchor:self.progressRing.bottomAnchor constant:50],
        [self.cardView.widthAnchor constraintEqualToConstant:300],
        [self.cardView.heightAnchor constraintEqualToConstant:80],
        
        // Shimmer View
        [self.shimmerView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.shimmerView.topAnchor constraintEqualToAnchor:self.cardView.bottomAnchor constant:50],
        [self.shimmerView.widthAnchor constraintEqualToConstant:250],
        [self.shimmerView.heightAnchor constraintEqualToConstant:60]
    ]];
}

- (void)gradientButtonTapped:(GradientButton *)sender {
    [self.loadingSpinner startAnimating];
    
    // Show success toast
    [ToastMessage showSuccessMessage:@"Button tapped successfully!" inView:self.view];
    
    // Update progress ring
    [self.progressRing setProgress:0.25 animated:YES];
    
    // Stop loading after 2 seconds
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self.loadingSpinner stopAnimating];
        [self.progressRing setProgress:1.0 animated:YES];
    });
}

@end 