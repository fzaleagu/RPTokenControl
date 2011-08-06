#import "RPTokenControl.h"
#import "RPBlackReflectionUtils.h"
#import "RPCountedToken.h"
#import "NSView+FocusRing.h"

#if 0
@interface NSString (Bonehead)
- (int)objectEnumerator ;
@end
@implementation NSString (Bonehead)
- (int)objectEnumerator  {
	return 0 ;
}
@end
#endif

id const SSYNoTokensMarker = @"SSYNoTokensMarker" ;
NSString* const RPTokenPboardType = @"RPTokenPboardType" ;
NSString* const RPTabularTokenPboardType = @"RPTabularTokenPboardType" ;

NSRange SSMakeRangeIncludingEndIndexes(int b1, int b2) {
	int diff, location ;
	if (b2 > b1) {
		diff = b2 - b1 ;
		location = b1 ;
	}
	else {
		// This will also work if b2=b1
		diff = b1 - b2 ;
		location = b2 ;
	}
	
	return NSMakeRange(location, diff + 1) ;
}

@interface NSObject (ExtractStringsFromCollection)

/*!
 @brief    If the receiver is a collection, returns a set containing the string
 objects and the texts of the RPCountedToken objects in the collection, or an
 empty set if there are none such.

 @details  If the receiver is not a collection, returns nil.
*/
- (NSSet*) extractStrings ;

@end

@implementation NSObject (ExtractStringsFromCollection)

- (NSSet*)extractStrings {
	if (![self conformsToProtocol:@protocol(NSFastEnumeration)]) {
		return nil ;
	}
	
	NSMutableSet* strings = [[NSMutableSet alloc] init] ;
	Class countedTokenClass = [RPCountedToken class] ;
	Class stringClass = [NSString class] ;
	for (id object in (NSObject <NSFastEnumeration> *)self) {
		NSString* string = nil ;
		if ([object isKindOfClass:countedTokenClass]) {
			string = [(RPCountedToken*)object text] ;
		}
		else if ([object isKindOfClass:stringClass]) {
			string = (NSString*)object ;
		}
		
		if (string) {
			[strings addObject:string] ;
		}
		else {
			NSLog(@"Internal Error 152-9184 %@", object) ;
		}
	}
	
	NSSet* output = [strings copy] ;
	[strings release] ;
	
	return [output autorelease] ;
}

@end

@interface FramedToken : NSObject {
	RPCountedToken* _token ;
	NSRect _bounds ;
	float _fontsize ;
}
@end

#define TCFillColorAttributeName @"TCFillColorAttributeName"
#define TCStrokeColorAttributeName @"TCStrokeColorAttributeName"

@implementation FramedToken

float const tokenBoxTextInset = 2.0 ;

+ (NSFont*)fontOfSize:(float)fontSize {
	return [NSFont labelFontOfSize:fontSize] ;
}

+ (NSSize)boxSizeForToken:(RPCountedToken*)token
				 fontSize:(float)fontSize
			  appendCount:(BOOL)appendCount {
	NSDictionary *attr = [NSDictionary dictionaryWithObject:[self fontOfSize:fontSize]
													 forKey:NSFontAttributeName] ;				
	NSString *str = appendCount ? [token textWithCountAppended] : [token text] ;
	NSSize size = [str sizeWithAttributes:attr] ;
	// Add whitespace around text, using R.P.'s secret formulas:
	size.width += 2*tokenBoxTextInset + (fontSize * 0.25) ;
	size.height += 2*tokenBoxTextInset ;
	return size ;
}

- (id)initWithCountedToken:(RPCountedToken*)token
				  fontsize:(float)f
					bounds:(NSRect)b {
	if((self = [super init])) {
		_token = [token retain] ;
		_fontsize = f;
		_bounds = b;
	}
	return self;
}
- (void)dealloc {
	[_token release];

	[super dealloc];
}

- (void)setBounds:(NSRect)b {
	_bounds = b ;
}

- (NSString*)text {
	return [_token text] ;
}

- (int)count {
	return [_token count] ;
}

- (NSRect)bounds {
	return _bounds ;
}

- (float)topEdge {
	return _bounds.origin.y ;
}

- (float)bottomEdge {
	return _bounds.origin.y + _bounds.size.height ;
}

- (float)midX {
	return _bounds.origin.x + _bounds.size.width/2 ;
}

- (float)midY {
	return _bounds.origin.y + _bounds.size.height/2 ;
}

- (float)distanceFrom:(NSPoint)point {
	float answer ;
	if (NSPointInRect(point, [self bounds])) {
		answer = 0.0 ;
	}
	else {
		float dx = (point.x - [self midX]) ;
		float dy = (point.y - [self midY]) ;
		return sqrt(dx*dx + dy*dy) ;
	}
	
	return answer ;
}

- (float)fontsize {
	return _fontsize ;
}

- (NSString*)description {
	return [NSString stringWithFormat:@"bounds=%@; fontSize=%f; count=%d; text=%@", NSStringFromRect([self bounds]), [self fontsize], [self count], [self text]] ;
}

- (void)drawWithAttributes:(NSDictionary*)attr
			   appendCount:(BOOL)appendCount {
    // In the following line, Robert's original code had "+1" appended to _bounds.origin.x and bounds.origin.y.
	// However, I found that this offset the words to the upper left corner of the rounded rects.  So,
	// I removed these offsets and now the tokens are centered in the rounded rects.
	NSRect rect = NSMakeRect(_bounds.origin.x, _bounds.origin.y, _bounds.size.width-3, _bounds.size.height-3) ;
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:rect
														  radius:rect.size.height*0.2] ;
    NSColor* color ;
	
	color = [attr objectForKey:TCFillColorAttributeName] ;
    if(color) {
		[color setFill] ; 
		[path fill] ;
	}    
	
    color = [attr objectForKey:TCStrokeColorAttributeName] ;
    if(color) {
		[color setStroke] ;
		[path stroke] ;
	}
    
	// Add font attribute to attr and draw the string
	attr = [NSMutableDictionary dictionaryWithDictionary:attr] ;
    [(NSMutableDictionary*)attr setObject:[FramedToken fontOfSize:_fontsize]
								   forKey:NSFontAttributeName] ;
    NSString* text = appendCount ? [_token textWithCountAppended] : [_token text] ;
	[text drawAtPoint:NSMakePoint(_bounds.origin.x+1+_fontsize*0.125, _bounds.origin.y+1)
	   withAttributes:attr];
}

- (RPCountedToken*)token {
	return _token ;
}

@end

//@interface NSSet (ConvertToRPCountedTokens)
//
//- (NSMutableArray*)copyAsMutableArrayOfCountedTokens ;
//
//@end
//
//@implementation NSSet (ConvertToRPCountedTokens) 
//
//- (NSMutableArray*)copyAsMutableArrayOfCountedTokens {
//	NSMutableArray* tokens = [[NSMutableArray alloc] init] ;
//	NSEnumerator* e = [self objectEnumerator] ;
//	id object ;
//	while ((object = [e nextObject])) {
//		int targetCount = [(NSCountedSet*)self countForObject:object] ;
//		
//		// Sort by count		
//		int i ;
//		for (i=0; i<[counts count]; i++) {
//			int currentCount = [[counts objectAtIndex:i] intValue] ;
//			if (targetCount <= currentCount) {
//				break ;
//			}
//		}
//		
//		
//		RPCountedToken* token = [[RPCountedToken alloc] initWithText:object
//														 count:targetCount] ;
//		[tokens insertObject:token atIndex:i]
//	}
//	
//	return tokens ;
//}
//
//@end


@interface RPTokenControl (Private)

// I try and order methods so that declarations are not required 
// for private methods to eliminate compiler warnings,
// but sometimes you just need one or two...
- (void)deselectAllIndexes ;
- (void)invalidateLayout ;

@end

@implementation RPTokenControl

#pragma mark * Constants

+ (void)initialize {
	[self exposeBinding:@"value"] ;
	[self exposeBinding:@"enabled"] ;
	[self exposeBinding:@"toolTip"] ;
	[self exposeBinding:@"fixedFontSize"] ;
}

+ (NSSet*)keyPathsForValuesAffectingSelectedTokens {
	return [NSSet setWithObjects:
			@"selectedIndexSet",
			nil] ;
}

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString*)key {
	BOOL automatic;
	
    if ([key isEqualToString:@"tokens"]) {
        // Because I want to only be observed when I've
		// confirmed that there was a substantiveChange.
		automatic = NO ;
    }
	else if ([key isEqualToString:@"selectedTokens"]) {
        automatic = NO ;
	}
	else {
        automatic = [super automaticallyNotifiesObserversForKey:key] ;
    }
    return automatic ;
}

- (float)defaultFontSize {
	return ([self fixedFontSize] == 0.0) ? _minFontSize : [self fixedFontSize] ;
}

- (float)fontSizeForToken:(RPCountedToken*)token
		   fromDictionary:(NSDictionary*)fontSizesForCounts {
	NSNumber* sizeObject = [fontSizesForCounts objectForKey:[NSNumber numberWithInt:[token count]]] ;
	float size ;
	if (sizeObject != nil) {
		size = [sizeObject floatValue] ;
	}
	else {
		size = [self defaultFontSize] ;
	}
	
	return size ;
}

const float minGap = 2.0 ; // Used for both horizontal and vertical gap between framedTokens

#pragma mark * Accessors

@synthesize dragImage = _dragImage ;
@synthesize tokenBeingEdited = _tokenBeingEdited ;
@synthesize delegate = _delegate ;
@synthesize disallowedCharacterSet = m_disallowedCharacterSet ;
@synthesize tokenizingCharacterSet = m_tokenizingCharacterSet ;
@synthesize noTokensPlaceholder = m_noTokensPlaceholder ;
@synthesize noSelectionPlaceholder = m_noSelectionPlaceholder ;
@synthesize multipleValuesPlaceholder = m_multipleValuesPlaceholder ;
@synthesize notApplicablePlaceholder = m_notApplicablePlaceholder ;

/*!
 @brief    Returns the current -objectValue if it is a collection,
 or nil if it is a state marker.
*/
- (id)tokensCollection {
	id value = [self objectValue] ;
	if ([value respondsToSelector:@selector(count)]) {
		return value ;
	}
	else {
		// Must be a state marker
		return nil ;
	}
}

/*!
 @brief    Returns the current -objectValue, repackaged into an array
 if it is not, returning an empty array if there are no objects.
*/
- (NSArray*)tokensArray {
	id collection = [self tokensCollection] ;
	NSArray* answer ;	
	if (!collection) {
		answer = [NSArray array] ;
	}
	else if ([collection isKindOfClass:[NSArray class]]) {
		answer = collection ;
	}
	else {
		// Must be a set
		answer = [collection allObjects] ;
	}
	
	return answer ;
}

/*!
 @brief    Returns the current -objectValue, repackaged into an set
 if it is not, returning an empty set if there are no objects.
 */
- (NSSet*)tokensSet {
	id collection = [self tokensCollection] ;
	NSSet* answer ;	
	if (!collection) {
		answer = [NSSet set] ;
	}
	else if ([collection isKindOfClass:[NSSet class]]) {
		answer = collection ;
	}
	else {
		// Must be an array
		answer = [NSSet setWithArray:collection] ;
	}

	return answer ;
}

- (unichar)tokenizingCharacter {
	unichar tokenizingCharacter ;
	@synchronized(self) {
		tokenizingCharacter = m_tokenizingCharacter ; ;
	}
	return tokenizingCharacter ;
}

- (void)setTokenizingCharacter:(unichar)tokenizingCharacter {
	@synchronized(self) {
		[self setTokenizingCharacterSet:[NSCharacterSet characterSetWithRange:NSMakeRange(tokenizingCharacter, 1)]] ;
		m_tokenizingCharacter = tokenizingCharacter ;
	}
}

+ (NSSet*)keyPathsForValuesAffectingTokenizingCharacterSet {
	return [NSSet setWithObjects:
			@"tokenizingCharacter",
			nil] ;
}

+ (NSSet*)keyPathsForValuesAffectingValue {
	return [NSSet setWithObjects:
			@"objectValue",
			nil] ;
}

- (id)objectValue {
	id objectValue ;
	@synchronized(self) {
		objectValue = [[m_objectValue retain] autorelease] ; ;
	}
	return objectValue ;
}

- (void)setObjectValue:(id)newTokens {
	if (!newTokens) {
		newTokens = SSYNoTokensMarker ;
	}
	
	BOOL isPlaceholder = ([newTokens extractStrings] == nil) ;
	
	BOOL substantiveChange ;
	id oldTokens ;
	
	@synchronized(self) {
		BOOL wasPlaceholder = ([m_objectValue extractStrings] == nil) ;

		if (isPlaceholder) {
			if (wasPlaceholder) {
				// is and was a placeholder
				substantiveChange = (newTokens != m_objectValue) ;
			}
			else {
				substantiveChange = YES ;
			}
		}
		else if (wasPlaceholder) {
			substantiveChange = YES ;
		}
		else {
			// is not and was not a placeholder
			substantiveChange = (
								 ((m_objectValue == nil) && (newTokens != nil))
								 ||
								 (![[m_objectValue extractStrings] isEqual:[newTokens extractStrings]])
								 ) ;	
		}			
		
		// If only some count(s) changed, but the strings remained the
		// same, we can keep the selection and layout, and do not trigger KVO
		[newTokens retain] ;
		if (substantiveChange) {
			[self willChangeValueForKey:@"objectValue"];
		}
		
		// Since oldTokens will be passed to the observer by
		// will/didChangeValueForKey, we can't release it until
		// after the notification has executed.  But, we'll
		// need a reference to do that.  So we now make
		// that reference:
		oldTokens = m_objectValue ;
		// before we change it:
		m_objectValue = newTokens ;
	}
	
    if (substantiveChange) {
		[self didChangeValueForKey:@"objectValue"];
	}
	// Now it is safe to do this:
	[oldTokens release] ;
	
	if (substantiveChange) {
		// String(s) changed
		[self deselectAllIndexes] ;
	}	
	
	[self invalidateLayout] ;
	[self setTokenBeingEdited:nil] ;
}

- (id)value {
	return [self objectValue] ;
}

- (void)setValue:(id)value {
	[self setObjectValue:value] ;
}

- (void)registerForDefaultDraggedTypes {
	[self registerForDraggedTypes:[NSArray arrayWithObjects:
								   NSStringPboardType,
								   NSTabularTextPboardType,
								   nil]] ;
}

- (NSString*)linkDragType {
	NSString* linkDragType ;
	@synchronized(self) {
		linkDragType = [[_linkDragType copy] autorelease] ; ;
	}
	return linkDragType ;
}

- (void)setLinkDragType:(NSString *)newLinkDragType {
    [newLinkDragType retain] ;
	@synchronized(self) {
		[_linkDragType release] ;
		_linkDragType = newLinkDragType ;
		if (_linkDragType != nil) {
			[self registerForDraggedTypes:[NSArray arrayWithObject:_linkDragType]] ;
		}
		else {
			[self unregisterDraggedTypes] ;
			[self registerForDefaultDraggedTypes] ;
		}
	}
}

- (NSTextField*)textField {
	if (_textField == nil) {
		_textField = [[NSTextField alloc] initWithFrame:[self frame]] ;
		// [self frame] is just to give it something.
		// It will be overwritten immediately, in -beginEditingNewTokenWithString:.
		[_textField setEnabled:YES] ;
		[_textField setEditable:YES] ;
		[_textField setBordered:NO] ;
		float fontSize = [self defaultFontSize] ;
		[_textField setFont:[FramedToken fontOfSize:fontSize]] ;
		[self addSubview:_textField] ;
		[_textField setDelegate:self] ;
	}
	
	return _textField ;
}

#pragma mark * Layout

const float halfRingWidth = 2.0 ;

- (NSMutableArray*)truncatedTokens {
	if (_truncatedTokens == nil) {
		_truncatedTokens = [[NSMutableArray alloc] init] ;
	}
	
	return _truncatedTokens ;
}

- (void)layoutLine:(NSArray*)line
				 y:(float)y
				 h:(float)h
			   gap:(float)gap
	focusRingFirst:(BOOL)focusRingFirst {
	float x = 1.0 ;
    if (focusRingFirst) {
		x += (halfRingWidth + tokenBoxTextInset) ;
	}
	y += 1.0;
	NSEnumerator *enumerator = [line objectEnumerator];
	FramedToken *layout;
	while (layout = [enumerator nextObject]) {
		NSRect bounds = [layout bounds];
		bounds.origin.x = x;
		bounds.origin.y = y + (h-bounds.size.height)/2;
		x += bounds.size.width + gap;
		[layout setBounds:bounds];
	}
}

- (void)doLayout {
	if(_framedTokens != nil) {
		return ;
	}
	_framedTokens = [[NSMutableArray alloc] init];
	
	id tokens = [self tokensCollection] ;
	if (!tokens) {
		return ;
	}
	
	//order by occurance and get the top n
	int len = [(NSSet*)tokens count];
	
	NSMutableArray* myTokens = [[NSMutableArray alloc] init] ;
	NSEnumerator* e = [(NSSet*)tokens objectEnumerator] ;
	RPCountedToken* token ;
	RPCountedToken* countedTokenEditing = nil ;
	id object ;
	if ([tokens respondsToSelector:@selector(countForObject:)]) {
		// tokens is a NSCountedSet of NSStrings
		while ((object = [e nextObject])) {
			int targetCount = [(NSCountedSet*)tokens countForObject:object] ;
			// Sometimes, if a token is being edited, the above can return 0.
			// Maybe this is a bug in NSCountedSet.  How can the token of a count
			// be 0, if it exists in the set???  So, I fix that with this line:
			targetCount = MAX(targetCount, 1) ;
			token = [[RPCountedToken alloc] initWithText:object
												   count:targetCount] ;
			[myTokens addObject:token] ;
			
			if (object == [self tokenBeingEdited]) {
				countedTokenEditing = token ;
			}
		}
	}
	else {
		// tokens is an NSArray or NSSet of: NSStrings and/or RPCountedTokens
		while ((object = [e nextObject])) {
			if (![object isKindOfClass:[RPCountedToken class]]) {
				// object must be a string (or results are undefined!)
				token = [[RPCountedToken alloc] initWithText:object
													   count:1] ;
				[myTokens addObject:token] ;
				[token release] ;
			}
			else {
				token = object ;
				[myTokens addObject:token] ;
			}
			
			if (object == [self tokenBeingEdited]) {
				countedTokenEditing = token ;
			}				
		}
	}
	// Sort tokens by their counts
	NSArray* sortedTokens = [myTokens sortedArrayUsingSelector:@selector(countCompare:)] ;
	[myTokens release] ;
	
	// Truncate the sortedTokens array to _maxTokensToDisplay
	NSRange displayedTokenRange = NSMakeRange(_firstTokenToDisplay, (len<_maxTokensToDisplay) ? len : _maxTokensToDisplay) ;
	// If we've removed tokens from the beginning, this must reduce
	// the length of the displayed range correspondingly:
	displayedTokenRange.length -= _firstTokenToDisplay ;
	sortedTokens = [sortedTokens subarrayWithRange:displayedTokenRange] ;
	
	// Create a dictionary for converting token counts to font size, in 2 steps
	NSMutableDictionary *fontSizesForCounts = [[NSMutableDictionary alloc] init];
	// Step 1 of 2.  Create a dictionary of key=count and value=rank
	int lastCnt = 0;
	e = [sortedTokens objectEnumerator];
	int cnt;
	while ((cnt = [[e nextObject] count])) {
		if(cnt == lastCnt) {
			continue ;
		}
		lastCnt = cnt;
		[fontSizesForCounts setObject:[NSNumber numberWithInt:[fontSizesForCounts count]] forKey:[NSNumber numberWithInt:cnt]];
	}
	// Dictionary values are now 'rank'.	
	// Step 2 of 2.  Replace each value, now 'rank', with a fontSize instead
	int weightMax = [fontSizesForCounts count] ;
	if(weightMax > 1) weightMax-- ;
	e = [[fontSizesForCounts allKeys] objectEnumerator] ;
	// Cannot use -keyEnumerator since we are going to mutate
	// fontSizesForCounts while enumerating through it
	NSNumber *key ;
	while (key = [e nextObject]) {
		float fontSize ;
		if ([self fixedFontSize] <= 0) {
			int weight = [[fontSizesForCounts objectForKey:key] intValue];
			float v = (weightMax-weight)*1.0/weightMax; // first=1.0, last = 0.0
			v = v*v; //non-linear curve so as to make the bigger ones even bigger
			fontSize = _minFontSize + v*(_maxFontSize-_minFontSize) ;
		}
		else {
			fontSize = [self fixedFontSize] ;
		}
		[fontSizesForCounts setObject:[NSNumber numberWithFloat:fontSize] forKey:key];
	}
	
	// Sort sortedTokens further, by their text this time
	sortedTokens = [sortedTokens sortedArrayUsingSelector:@selector(textCompare:)] ;
	
	// Format tokens
	float wholeWidth = [self frame].size.width ;
	float maxHeight = 0.0 ;
	NSPoint pt = NSMakePoint(0.0, minGap) ;
	// minGap here is to leave a little whitespace (or blackspace, as the case may be)
	// between the top of the view and the top of the first row of tokens
	e = [sortedTokens objectEnumerator];	
	id currentToken;
	NSMutableArray *currentLine = [[NSMutableArray alloc] init] ;
	// We would like to lay out each line of tokens as it is completed,
	// however we cannot quite do this because:
	//   (1) the last line is to be left-aligned instead of justified (spread).
	//   (2) If we have no enclosing scroll view the "last" line may have to be
	//     eliminated (truncated off) if it does not fit.
	//   (3) We don't know that until we find out how high its highest token is (maxHeight).
	// So, because of all this we have to store information about the
	// "previous" line, and wait until the end to lay out the last
	// line (which will be the currentLine) and the second-last line
	// (which will be the previousLine.
	NSArray* previousLine = nil ;
	float previousLineTokensWidth ;
	float previousLineY ;
	float previousLineMaxHeight ;
	NSScrollView* scrollView = [self enclosingScrollView] ;
	NSRect frame = [self frame] ;
	NSMutableArray* truncatedTokens = [self truncatedTokens] ;
	[truncatedTokens removeAllObjects] ;
	
	int i = 0 ;
	BOOL focusRingLeftOfFirstToken = NO ;
	_indexOfFramedTokenBeingEdited = NSNotFound ;
	while (currentToken = [e nextObject]) {
		float fontSize = [self fontSizeForToken:currentToken
								 fromDictionary:fontSizesForCounts] ;
		NSSize framedTokenSize = [FramedToken boxSizeForToken:currentToken
													 fontSize:fontSize
												  appendCount:_appendCountsToStrings] ;
		
		// If the first token is being edited, provide a little extra margin on the left
		// for the focus ring, because _textField will be set to a frame which is 
		// based on the frame of the FramedToken we are about to create.
		if ((i==0) && (currentToken == countedTokenEditing)) {
			focusRingLeftOfFirstToken = YES ;
		}
		
		if((pt.x+minGap+framedTokenSize.width > wholeWidth) && (pt.x > 0)) {
			// Horizontal overflow.  Put the currentToken on 'hold'.  It will
			// go into the ^next^ line.  Now, we do several finalization tasks
			// on the current line and the previous line...
			
			// Before dealing with the current line, we see if there was a 
			// ^previous^ line that needs to be finalized.
			if (previousLine) {
				// Since we have now overflowed into a ^new^ line, we know that
				// the ^previous^ line is ^not^ the last line, therefore we are 
				// now certain that it should be laid out with justification (spreading).
				// We now do that, adding the FramedTokens from previousLine, with
				// layout information, to _framedTokens.
				// The 'gap' is the amount of space between tokens.
				// In this case it is calculated to justify or "spread" the tokens.
				int nGaps = [previousLine count] - 1 ;
				float extraWidth = wholeWidth - previousLineTokensWidth ;
				float gap = minGap + extraWidth/nGaps ;
				[self layoutLine:previousLine
							   y:previousLineY
							   h:previousLineMaxHeight
							 gap:gap
				  focusRingFirst:focusRingLeftOfFirstToken] ;
				focusRingLeftOfFirstToken = NO ;
				[_framedTokens addObjectsFromArray:previousLine];
				[previousLine release] ;
			}
			
			// If superview does not scroll, see if we can fit more tokens
			if ((scrollView==nil) && (pt.y + maxHeight > frame.size.height)) {
				// Vertical overflow in a non-scrolling view
				
				// Replace the proposed currentToken (which caused an overflow)
				// with an ellipsisToken
				[truncatedTokens addObject:currentToken] ;
				currentToken = [RPCountedToken ellipsisToken] ;
				fontSize = [self fontSizeForToken:currentToken
								   fromDictionary:fontSizesForCounts] ;
				
				framedTokenSize = [FramedToken boxSizeForToken:currentToken
													  fontSize:fontSize
												   appendCount:_appendCountsToStrings] ;
				
				// See if it fits now, and if not, remove tokens previously added
				// to currentLine until it does fit.
				while (pt.x+minGap+framedTokenSize.width > wholeWidth) {
					FramedToken* tokenToRemove = [currentLine lastObject] ;
					float reclaimedWidth = [tokenToRemove bounds].size.width + minGap ;
					if ([currentLine count] < 1) {
						// Should never happen but I'm not sure
						NSLog(@"Internal Error 638-4882") ;
						break ;
					}
					[currentLine removeLastObject] ;
					pt.x -= reclaimedWidth ;
				}
				
				// Add the ellipsisToken (now currentToken)
				FramedToken *framedToken = [[FramedToken alloc] initWithCountedToken:currentToken
																			fontsize:fontSize
																			  bounds:NSMakeRect(0, 0, framedTokenSize.width, framedTokenSize.height)];
				[currentLine addObject:framedToken] ;
				[framedToken release] ;
				
				break ;
			}
			
			previousLine = [currentLine copy] ;
			previousLineTokensWidth = pt.x ;
			previousLineY = pt.y ;
			previousLineMaxHeight = maxHeight ;
			// Clear everything out in preparation for next line
			float currentLineHeight = maxHeight + minGap ;
			// Note that this view uses a flipped y coordinate.
			// That makes it easier because now we can simply
			// increase y to move the next line down...
			pt.y += currentLineHeight ;
			// ... and no need to displace any of the previous lines.
			[currentLine removeAllObjects];
			maxHeight = 0.0;
			pt.x = 0;
		}
		FramedToken *framedToken = [[FramedToken alloc] initWithCountedToken:currentToken
																	fontsize:fontSize
																	  bounds:NSMakeRect(0, 0, framedTokenSize.width, framedTokenSize.height)];
		[currentLine addObject:framedToken] ;
		[framedToken release] ;
		
		if(pt.x > 0) {
			pt.x += minGap ;
		}
		pt.x += framedTokenSize.width;
		
		if(framedTokenSize.height > maxHeight) {
			maxHeight = framedTokenSize.height ;
		}
		
		if (currentToken == countedTokenEditing) {
			_indexOfFramedTokenBeingEdited = i ;
		}
		i++ ;
	}
	
	// Add any remaining tokens (which did not fit) to truncatedTokens
	while (currentToken = [e nextObject]) {
		[truncatedTokens addObject:currentToken] ;
	}
	
	// Lay out the second-last line.
	if ([previousLine count] > 0) {
		// gap is the amount of space between tokens.
		// In this case it is calculated for each line to justify or "spread" the tokens.
		int nGaps = [previousLine count] - 1 ;
		float extraWidth = wholeWidth - previousLineTokensWidth ;
		float gap = minGap + extraWidth/nGaps ;
		[self layoutLine:previousLine
					   y:previousLineY
					   h:previousLineMaxHeight
					 gap:gap
		  focusRingFirst:focusRingLeftOfFirstToken] ;
		focusRingLeftOfFirstToken = NO ;
		[_framedTokens addObjectsFromArray:previousLine];
		[previousLine release] ;
	}
	
	// Lay out the last line.
	// This one is different because it is left-aligned instead of justified.
	// So, we use gap = minGap
	if ([currentLine count] > 0) {
		[self layoutLine:currentLine
					   y:pt.y
					   h:maxHeight
					 gap:minGap
		  focusRingFirst:focusRingLeftOfFirstToken] ;			
	}
	[_framedTokens addObjectsFromArray:currentLine] ;
	[currentLine release] ;
	
	// If in a scroll view, increase heght and add scroller if needed
	float requiredHeight = pt.y + maxHeight ;
	float scrollViewHeight = scrollView ? [scrollView frame].size.height : 0.0 ;
	// Must set the lockout here because -setHasVerticalScroller can invoke our -setFrameSize
	_isDoingLayout = YES ;
	if (scrollView == nil) {
		// No scroll view, so do not change the frame size
	}
	else if (requiredHeight > scrollViewHeight) {
		frame.size.height = requiredHeight ;
		[scrollView setHasVerticalScroller:YES] ;
	}
	else {
		frame.size.height = scrollViewHeight ;
		[scrollView setHasVerticalScroller:NO] ;
	}
	if (scrollView) {
		frame.size.width = [NSScrollView contentSizeForFrameSize:[scrollView frame].size
										   hasHorizontalScroller:[scrollView hasHorizontalScroller] // Never been tested with horiz scroller
											 hasVerticalScroller:[scrollView hasVerticalScroller]
													  borderType:[scrollView borderType]].width ; 
	}
	[self setFrameSize:frame.size] ;
	_isDoingLayout = NO ;
	
	
	// Remove old toolTips
	// Remember this, because, -removeAllToolTips removes both
	// the view-wide toolTip and the rect toolTips.
	NSString* wholeViewToolTip = [[self toolTip] retain] ;
	// Yes, it will crash if I don't retain it.
	[self removeAllToolTips] ;
	if (wholeViewToolTip != nil) {
		[self setToolTip:wholeViewToolTip] ;
		[wholeViewToolTip release] ;
	}
	// Add new toolTip rects
	{
		e = [_framedTokens objectEnumerator] ;
		FramedToken *framedToken ;
		while(framedToken = [e nextObject]) {
			[self addToolTipRect:[framedToken bounds]
						   owner:self
						userData:framedToken] ;
		}
	}
}

- (void)invalidateLayout {
	[_framedTokens release];
	_framedTokens = nil;
	[self doLayout] ;
	[self setNeedsDisplay:YES];
}


#pragma mark * Selection Management

- (NSIndexSet*)selectedIndexSet {
	return [[_selectedIndexSet copy] autorelease] ;
}


- (void)setSelectedIndexSet:(NSIndexSet*)newSelectedIndexSet {
	[_selectedIndexSet release] ;
	_selectedIndexSet = [newSelectedIndexSet copy] ;
}

- (NSIndexSet*)deselectedIndexesSet {
	// Too bad Apple doesn't provide a -minusSet method for NSIndexSet...
	NSMutableIndexSet* deselectedIndexesSet = [[NSMutableIndexSet alloc] init] ;
	int i ;
	id value = [self tokensCollection] ;
	for (i=0; i<[(NSSet*)value count]; i++) {
		if (![[self selectedIndexSet] containsIndex:i]) {
			[deselectedIndexesSet addIndex:i] ;
		}
	}
	
	NSIndexSet* output = [deselectedIndexesSet copy] ;
	[deselectedIndexesSet release] ;
	
	return [output autorelease] ;
}

- (void)selectIndex:(int)index {
	NSMutableIndexSet* selectedIndexSet = [[self selectedIndexSet] mutableCopy] ;
	if (![selectedIndexSet containsIndex:index]) {
		[selectedIndexSet addIndex:index] ;
		[self setSelectedIndexSet:selectedIndexSet] ;
		_lastSelectedIndex = index ;
		FramedToken* framedToken = [_framedTokens objectAtIndex:index] ;
		[self setNeedsDisplayInRect:[framedToken bounds]] ;
	}
	[selectedIndexSet release] ;
}

- (void)deselectIndex:(int)index {
	NSMutableIndexSet* selectedIndexSet = [[self selectedIndexSet] mutableCopy] ;
	if ([selectedIndexSet containsIndex:index]) {
		[selectedIndexSet removeIndex:index] ;
		[self setSelectedIndexSet:selectedIndexSet] ;
		FramedToken* framedToken = [_framedTokens objectAtIndex:index] ;
		[self setNeedsDisplayInRect:[framedToken bounds]] ;
	}
	[selectedIndexSet release] ;
}

- (void)selectIndexesInRange:(NSRange)range {
	int lastIndexToSelect = range.location + range.length - 1;
	NSMutableIndexSet* selectedIndexSet = [[self selectedIndexSet] mutableCopy] ;
	if (![selectedIndexSet containsIndexesInRange:range]) {
		
		int firstIndexToSelect = range.location ;
		NSIndexSet* deselectedIndexesSet = [self deselectedIndexesSet] ;
		// Loop through those members of the deselectedIndexesSet
		// which intersect the 'range' of indexes to select
		// For each one found, select it and mark its box as needing display
		unsigned int i = [deselectedIndexesSet indexGreaterThanOrEqualToIndex:firstIndexToSelect] ;
		while (i<=lastIndexToSelect) {
			[selectedIndexSet addIndex:i] ;
			FramedToken* token = [_framedTokens objectAtIndex:i] ;
			[self setNeedsDisplayInRect:[token bounds]] ;
			i = [deselectedIndexesSet indexGreaterThanIndex:i] ;
		}
		
		[self setSelectedIndexSet:selectedIndexSet] ;
	}
	[selectedIndexSet release] ;
	_lastSelectedIndex = lastIndexToSelect ;
}

- (void)deselectAllIndexes {
	//  Will only do something if >0 now selected
	NSMutableIndexSet* selectedIndexSet = [[self selectedIndexSet] mutableCopy] ;
	if ([selectedIndexSet count] > 0 ) {
		
		// Mark all which are now selected as needing display
		// since they will all be deselected
		unsigned int i = [selectedIndexSet firstIndex] ;
		while ((i != NSNotFound)) {
			// If the last token was deleted, its index will still 
			// be in the selectedIndexSet, so we check that i
			// is not too big before proceeding.
			if (i < [_framedTokens count]) {
				FramedToken* token = [_framedTokens objectAtIndex:i] ;
				[self setNeedsDisplayInRect:[token bounds]] ;
			}
			i = [selectedIndexSet indexGreaterThanIndex:i] ;
		}
		
		[selectedIndexSet removeAllIndexes] ;		
		[self setSelectedIndexSet:selectedIndexSet] ;
	}
	[selectedIndexSet release] ;
	
	_lastSelectedIndex = NSNotFound ;
}

- (void)selectAllIndexes {
	id tokens = [self tokensCollection] ;
	//  Will only do something if all not now selected
	NSMutableIndexSet* selectedIndexSet = [[self selectedIndexSet] mutableCopy] ;
	if ([selectedIndexSet count] < [(NSSet*)tokens count]) {
		
		// Mark all which are now not selected as needing display
		// since they will all be selected
		NSIndexSet* deselectedIndexesSet = [self deselectedIndexesSet] ;
		unsigned int i = [deselectedIndexesSet firstIndex] ;
		while ((i != NSNotFound)) {
			FramedToken* token = [_framedTokens objectAtIndex:i] ;
			[self setNeedsDisplayInRect:[token bounds]] ;
			i = [deselectedIndexesSet indexGreaterThanIndex:i] ;
		}
		
		[selectedIndexSet addIndexesInRange:NSMakeRange(0, [(NSSet*)tokens count])] ;		
		[self setSelectedIndexSet:selectedIndexSet] ;
	}
	_lastSelectedIndex = [selectedIndexSet lastIndex] ;
	
	[selectedIndexSet release] ;
}

- (void)setMaxTokensToDisplay:(int)maxTokensToDisplay {
    _maxTokensToDisplay = maxTokensToDisplay;
	[self deselectAllIndexes] ;
    [self invalidateLayout];
}

- (void)setShowsReflections:(BOOL)yn {
    _showsReflections = yn ;
    [self setNeedsDisplay:YES] ;
}

- (void)setBackgroundWhiteness:(float)whiteness {
	_backgroundWhiteness = whiteness ;
    [self setNeedsDisplay:YES] ;
}

- (void)setShowsCountsAsToolTips:(BOOL)yn {
    _showsCountsAsToolTips = yn ;
}

- (void)setAppendCountsToStrings:(BOOL)yn {
    _appendCountsToStrings = yn ;
}

- (void)setEditable:(BOOL)yn {
	_isEditable = yn ;
	if (yn) {
		[self registerForDefaultDraggedTypes] ;
	}
	else {
		[self unregisterDraggedTypes] ;
		// Since the above clears all dragged types, we have to
		// re-register the custom type, if one has been set.
		NSString* linkDragType = [self linkDragType] ;
		if (linkDragType != nil) {
			[self registerForDraggedTypes:[NSArray arrayWithObject:linkDragType]] ;
		}
	}  
}

- (void)setMinFontSize:(float)x {
	_minFontSize = x ;
    [self invalidateLayout];
}

- (void)setMaxFontSize:(float)x {
	_maxFontSize = x ;
    [self invalidateLayout];
}

- (CGFloat)fixedFontSize {
	CGFloat fixedFontSize ;
	@synchronized(self) {
		fixedFontSize = m_fixedFontSize ; ;
	}
	return fixedFontSize ;
}

- (void)setFixedFontSize:(float)x {
	@synchronized(self) {
		m_fixedFontSize = x ;
	}
    [self invalidateLayout];
}

- (void)setFrameSize:(NSSize)size {
	[super setFrameSize:size];
	if (!_isDoingLayout) {
		[self invalidateLayout] ;
	}
	
}

#pragma mark * Select/Deselect Tokens

- (BOOL)isSelectedIndex:(int)index {
	BOOL isSelected = NO ;
	if (index != NSNotFound) {
		isSelected = [[self selectedIndexSet] containsIndex:index] ;
	}
	
	return isSelected ;
}

- (BOOL)isSelectedFramedToken:(FramedToken*)framedToken {
	int index = [_framedTokens indexOfObject:framedToken] ;
	return [self isSelectedIndex:index] ;
}

- (NSArray*)selectedTokens {
	NSEnumerator* e = [_framedTokens objectEnumerator] ;
	NSMutableArray* selectedTokens = [[NSMutableArray alloc] init] ;
	FramedToken* framedToken ;
	while ((framedToken = [e nextObject])) {
		if ([self isSelectedFramedToken:framedToken]) {
			[selectedTokens addObject:[framedToken text]] ;
		}
	}
	
	NSArray* output = [selectedTokens copy] ;
	[selectedTokens release] ;
	
	return output ;
}

#pragma mark * Typing In New Tokens

- (void)updateTextFieldFrame {
	// This method must be preceded by -invalidateLayout or -doLayout, in order
	// to update _indexOfFramedTokenBeingEdited.
	
	// If the token being edited overflows the view and is not being drawn
	// _indexOfFramedTokenBeingEdited will be NSNotFound.  In that case, we
	// do not update the text field frame.  It will just stay at the last
	// location and size that it was before the overflow occurred.
	if (_indexOfFramedTokenBeingEdited != NSNotFound) {
		FramedToken* framedTokenBeingEdited = [_framedTokens objectAtIndex:_indexOfFramedTokenBeingEdited] ;
		NSRect rect = [framedTokenBeingEdited bounds] ;
		// The next three lines tweak the rect of the NSTextField to kind of
		// match the FramedToken which it temporarily replaces.  I could give an
		// analysis of why the following three adjustments are correct by
		// noting their symmetry to those in -[FramedToken boxSizeForToken:::],
		// but they're not quite.  This has not yet been tested with font sizes
		// other than fixedFontSize = 11.0.
		rect.origin.y += 1.0 ;
		rect.size.width += 0.0 ; //(2*tokenBoxTextInset + ([framedTokenBeingEdited fontsize] * 0.25)) ;
		rect.origin.x -= 2*tokenBoxTextInset ;
		rect.size.height -= 2*tokenBoxTextInset ;
		NSTextField* textField = [self textField] ;
		[textField setFrame:rect] ;
	}
}	

- (void)beginEditingNewTokenWithString:(NSString*)string {
	// Ordinarily, string is one character, the first character typed.
	id newTokens ;
	if ([m_objectValue respondsToSelector:@selector(mutableCopy)]) {
		newTokens = [m_objectValue mutableCopy] ;
	}
	else {
		newTokens = [[NSMutableArray alloc] init] ;
	}

	NSMutableString* mutableString = [string mutableCopy] ;
	[newTokens addObject:mutableString] ;
	[self setTokenBeingEdited:mutableString] ;
	[mutableString release] ;
	// We set the ivar directly here to avoid triggering KVO
	[m_objectValue release] ;
	m_objectValue = newTokens ;
	[self deselectAllIndexes] ;
	[self invalidateLayout] ;
	
	NSTextField* textField = [self textField] ;
	[textField setStringValue:mutableString] ;
	[[self window] makeFirstResponder:textField] ;
	// The next step is to deselect the text (one character) and
	// move the insertion point to the end.  NSTextField does not
	// have any methods to do this, but the field editor does:
	NSText* fieldEditor = [[self window] fieldEditor:NO
										   forObject:textField] ;
	[fieldEditor setSelectedRange:NSMakeRange(1,0)] ;
	// Note that the insertion point is always set to the ^end^
	// of the selectedRange.
	
	[textField setHidden:NO] ;
	
	[self updateTextFieldFrame] ;
}

-  (void)controlTextDidChange:(NSNotification*)notification {
	NSTextField* textField = [self textField] ;
	NSString* newText = [[self textField] stringValue] ;

	// Check for tokenizing character
	NSInteger lastIndex = [newText length] - 1 ;
	if (lastIndex >= 0) {
		unichar newChar = [newText characterAtIndex:lastIndex] ;
		if ([[self tokenizingCharacterSet] characterIsMember:newChar]) {
			// Found tokenizing character.  End it.
			[textField setStringValue:[newText substringToIndex:lastIndex]] ;
			[self controlTextDidEndEditing:nil] ;
		}
	}

	// Check for disallowed character
	NSCharacterSet* disallowedCharacterSet = [self disallowedCharacterSet] ;
	if (disallowedCharacterSet != nil) {
		int badCharLocation = [newText rangeOfCharacterFromSet:disallowedCharacterSet].location ;
		// Since we check this every time a character is entered, there
		// should only be one bad character at most
		if (badCharLocation != NSNotFound) {
			NSMutableString* fixedToken = [newText mutableCopy] ;
			[fixedToken replaceCharactersInRange:NSMakeRange(badCharLocation,1)
									  withString:@"_"] ;
			[textField setStringValue:fixedToken] ;
			newText = [fixedToken autorelease] ;
			NSBeep() ;	
		}
	}
	[[self tokenBeingEdited] setString:newText] ;
	[self invalidateLayout] ;
	[self updateTextFieldFrame] ;
}

-  (void)controlTextDidEndEditing:(NSNotification*)notification {
	NSTextField* textField = [self textField] ;
	[textField setHidden:YES] ;
	
	// Finalize this token:
	// Make the new token immutable and trigger automatic KVO for observers of tokens.
	id tokens = [self tokensCollection] ;
	if (!tokens) {
		return ;
	}
	
	NSString* tokenEditing = [self tokenBeingEdited] ;
	// This method seems to get invoked when you just click on the field.
	// Not sure why.  It's Cocoa.
	// Exceptions will be raised in what follows if tokenEditing == nil,
	// so we guard against that
	if (!tokenEditing) {
		return ;
	}

	[tokens removeObject:tokenEditing] ;
	NSString* newToken = [tokenEditing copy] ;
	[tokens addObject:newToken] ;
	[newToken release] ;
	// Next two lines are so that substantiveChange will be detected
	[m_objectValue release] ;
	m_objectValue = nil ;
	// Now, we trigger KVO
	[self setObjectValue:tokens] ;
	[tokens release] ;
	[[self window] makeFirstResponder:self] ;
}

#pragma mark * Mouse Handling

- (int)indexOfTokenClosestToPoint:(NSPoint)pt
					 excludeToken:(FramedToken*)excludedToken
			excludeHigherNotLower:(BOOL)excludeHigherNotLower {
	// The last argument says whether to exclude tokens that
	// are ^higher^ than excludedToken, or exclude tokens that
	// are ^lower^ than excludedToken.
	int index = NSNotFound ;
	
	if (
		(pt.y >= 0.0)
		&& (pt.y <= [self frame].size.height)
		&& (pt.x >= 0.0)
		&& (pt.x <= [self frame].size.width)
		) {	
		FramedToken* framedToken ;
		float distance ;
		int direction = excludeHigherNotLower ? +1 : -1 ;
		float yLimit = direction * [excludedToken midY] ;
		int nTokens = [_framedTokens count] ;
		
		NSMutableArray* distances = [[NSMutableArray alloc] initWithCapacity:nTokens] ;
		int i ;
		for (i=0; i<nTokens; i++) {
			framedToken = [_framedTokens objectAtIndex:i] ;
			if ((framedToken == excludedToken) || ([framedToken midY]*direction < yLimit)) {
				distance = FLT_MAX ;
			}
			else {
				distance = [framedToken distanceFrom:pt] ;
			}
			
			if (distance == 0.0) {
				// pt is inside this token.  That's our answer
				// This will not always happen
				break ;
			}
			else {
				[distances addObject:[NSNumber numberWithFloat:distance]] ;
			}
		}
		
		if (distance == 0.0) {
			// pt is inside a token
			index = i ;
		}
		else {
			// pt is not inside any token, must search for minimum
			float minDistance = FLT_MAX ;
			for (i=0; i<nTokens; i++) {
				distance = [[distances objectAtIndex:i] floatValue] ;
				if (distance < minDistance) {
					index = i ;
					minDistance = distance ;
				}
			}
		}
		
		[distances release] ;
	}
	
	return index ;
}

- (FramedToken*)tokenAtPoint:(NSPoint)pt {
	FramedToken* token = nil ;
	NSEnumerator *enumerator = [_framedTokens objectEnumerator] ;
	FramedToken *framedToken;
	while(framedToken = [enumerator nextObject]) {
		if(NSPointInRect(pt, [framedToken bounds])) { 
			token = framedToken ;
			break ;
		}
	}
	
	return token ;
}

- (void)scrollIndexToVisible:(int)index {
	if (index < [_framedTokens count]) {
		NSScrollView* scrollView = [self enclosingScrollView] ;
		if (scrollView != nil) {
			FramedToken* framedToken = [_framedTokens objectAtIndex:index] ;
			if (framedToken != nil) {
				NSRect bounds = [framedToken bounds] ;
				[self scrollRectToVisible:bounds] ;
			}
		}
	}
}


- (BOOL)ellipsisTokenIsDisplayed {
	BOOL answer = NO ;
	id lastFramedToken = [_framedTokens lastObject] ;
	if (lastFramedToken != nil) {
		if ([[lastFramedToken token] isEllipsisToken]) {
			answer = YES ;
		}
	}
	return answer ;
}


// The following method is invoked for
//		mouse clicks
//      arrow-key actions
//		drags of linkDragType objects into the view.
- (void)changeSelectionPerUserActionAtIndex:(int)index {
	
	int nNonEllipsisFramedTokens = [_framedTokens count] ;
	if ([self ellipsisTokenIsDisplayed]) {
		nNonEllipsisFramedTokens-- ;
	}
	
	BOOL canSelect = NO ;
	if (index < 0) {
		if (_firstTokenToDisplay > 0) {
			_firstTokenToDisplay-- ;
			[self invalidateLayout] ;
		}
		else {
			NSBeep() ;
		}
	}
	else if (index >= nNonEllipsisFramedTokens) {
		
		if ([[self truncatedTokens] count] > 0) {
			_firstTokenToDisplay++ ;
			[self invalidateLayout] ;
			// Note that the above action may change whether
			// or not an ellipsisToken is displayed
			index = [_framedTokens count] - 1 ;
			// If the last token is an ellipsisToken, decrement
			// the index to select the prior token instead
			if ([self ellipsisTokenIsDisplayed]) {
				index-- ;
			}	
			canSelect = YES ;
		}
		else {
			canSelect = NO ;
			NSBeep() ;
		}
	}
	else {
		canSelect = YES ;
	}
	
	if (canSelect) {
		int unsigned modifierFlags = [[NSApp currentEvent] modifierFlags] ;
		BOOL shiftKeyDown = ((modifierFlags & NSShiftKeyMask) != 0) ;
		BOOL cmdKeyDown = ((modifierFlags & NSCommandKeyMask) != 0) ;
		if (index != NSNotFound) {
			if (cmdKeyDown) {
				if ([self isSelectedIndex:index]) {
					// Deselect  it
					[self deselectIndex:index] ;
				}
				else {
					// Select it
					[self selectIndex:index] ;
				}
			}
			else if (shiftKeyDown) {
				// Extend selection to include clicked token
				if (_lastSelectedIndex != NSNotFound) {
					// Add the acted-on token and all contiguous with last selected index
					NSRange range = SSMakeRangeIncludingEndIndexes(index, _lastSelectedIndex) ;
					[self selectIndexesInRange:range] ;
				}
				else {
					// Just add the acted-on token
					[self selectIndex:index] ;
				}
				// Remember this one for next extension of selection
				_lastSelectedIndex = index ;
				
			}
			else {
				// A token was acted on with no modifier key down
				[self deselectAllIndexes] ;
				[self selectIndex:index] ;
			}
		}			
		[self scrollIndexToVisible:index] ;
	}
	
}


- (void)changeSelectionPerUserActionAtFramedToken:(FramedToken*)framedToken {
	[self changeSelectionPerUserActionAtIndex:[_framedTokens indexOfObject:framedToken]] ;
}

/* This method only gets the navigation keystrokes, deletes, and the first
 keystroke of a new tag.  After the first keystroke, the field editor
 takes over, and code in controlTextDidChange: gets the result. */
- (void)keyDown:(NSEvent*)event {
	NSString *s = [event charactersIgnoringModifiers] ;
	unichar keyChar = 0 ;
	if ([s length] == 1) {
		keyChar = [s characterAtIndex:0] ;
		if (
			(keyChar == NSLeftArrowFunctionKey) 
			|| (keyChar == NSRightArrowFunctionKey)
			|| (keyChar == NSUpArrowFunctionKey)
			|| (keyChar == NSDownArrowFunctionKey)
			) {
			// User has typed one of the four arrow keys
			// Change or extend the selection
			
			id tokens = [self tokensCollection] ;
			if (!tokens) {
				NSBeep() ;
				return ;
			}
			
			FramedToken* lastSelectedToken ;
			NSPoint target ;
			float margin ;
			
			// If necessary, switch _lastSelectedIndex to match the
			// direction in which the user is headed
			NSIndexSet* selectedIndexSet = [self selectedIndexSet] ;
			if (
				(keyChar == NSLeftArrowFunctionKey) 
				|| (keyChar == NSUpArrowFunctionKey)
				) {			
				// User is heading up
				_lastSelectedIndex = [selectedIndexSet firstIndex] ;
				if (_lastSelectedIndex != NSNotFound) {
					lastSelectedToken = [_framedTokens objectAtIndex:_lastSelectedIndex] ;
				}
				else {
					lastSelectedToken = [_framedTokens lastObject] ;
				}
			}
			else {
				// User is heading down
				_lastSelectedIndex = [selectedIndexSet lastIndex] ;
				if (_lastSelectedIndex != NSNotFound) {
					lastSelectedToken = [_framedTokens objectAtIndex:_lastSelectedIndex] ;
				}
				else if ([_framedTokens count] > 0) {
					lastSelectedToken = [_framedTokens objectAtIndex:0] ;
				}
				else {
					lastSelectedToken = nil ;
				}
			}
			
			int index = NSNotFound ;
			switch(keyChar) {
				case NSLeftArrowFunctionKey:
					if (_lastSelectedIndex == NSNotFound) {
						index = [tokens count] - 1 ;
					}
					else {
						index = _lastSelectedIndex - 1 ;
					}						
					break ;
					case NSRightArrowFunctionKey: 
					if (_lastSelectedIndex == NSNotFound) {
						index = 0 ;
					}
					else {
						index = _lastSelectedIndex + 1 ;
					}
					
					break ;
					case NSUpArrowFunctionKey:
					case NSDownArrowFunctionKey:
					// Up and down arrow keys are much more complicated...
					margin = minGap + MAX([self fixedFontSize], _minFontSize) / 2 ;
					if (keyChar==NSUpArrowFunctionKey) {
						target.y = [lastSelectedToken topEdge] - margin ;
					}
					else {
						target.y = [lastSelectedToken bottomEdge] + margin ;
					}
					
					target.x = [lastSelectedToken midX] ;
					index = [self indexOfTokenClosestToPoint:target
												excludeToken:lastSelectedToken
									   excludeHigherNotLower:(keyChar==NSDownArrowFunctionKey)] ;
					break ;
			}
			[self changeSelectionPerUserActionAtIndex:index] ;
		}
		else if (keyChar == '\e') { // the 0x1b ASCII 'escape'
			// User has clicked the 'escape' key
			[self deselectAllIndexes] ;
		}
		else if (_isEditable) {
			if (keyChar == NSDeleteCharacter) {
				// User has clicked the 'delete' key
				// Delete the selected tokens
				
				if ([[self selectedIndexSet] count] > 0) {
					// Get the tokensToDelete from _framedTokens and selectedIndexSet
					NSArray* framedTokensToDelete = [_framedTokens objectsAtIndexes:[self selectedIndexSet]] ; 
					NSArray* stringsToDelete = [framedTokensToDelete valueForKey:@"text"] ;
					NSMutableSet* tokensToDelete = [[self tokensSet] mutableCopy] ;
					if (!tokensToDelete) {
						return ;
					}
					[tokensToDelete intersectSet:[NSSet setWithArray:stringsToDelete]] ;
					
					// Remove the tokensToDelete from m_tokens
					id tokens = [self tokensCollection] ;
					if (!tokens) {
						// Must be a state marker.  Nothing to delete.
						return ;
					}
					id newTokens = [tokens mutableCopy] ;
					if ([tokens respondsToSelector:@selector(removeObjectsInArray)]) {
						// Must be an NSMutableArray
						[newTokens removeObjectsInArray:[tokensToDelete allObjects]] ;
					}
					else if ([tokens respondsToSelector:@selector(minusSet:)]) {
						// Must be an NSMutableSet
						[newTokens minusSet:tokensToDelete] ;
					}
					// Invoke the KVC-compliant setter
					[self setObjectValue:newTokens] ;
					[newTokens release] ;
					
					// Deselect the selected tokens
					[self deselectAllIndexes] ;
					[self invalidateLayout] ;
					
					[[self window] makeFirstResponder:self] ;
				}
			}
			else {
				[self beginEditingNewTokenWithString:s] ;
			}
		}
	}
	else if (_isEditable) {
		[self beginEditingNewTokenWithString:s] ;
	}
}

// HARD WAY TO SELECT ALL.  Also gets crosstalk between clouds
//- (BOOL)performKeyEquivalent:(NSEvent *)event {
//	NSString *s = [event charactersIgnoringModifiers] ;
//	unichar keyChar = 0 ;
//	BOOL didDo = NO ;
//	if ([s length] == 1) {
//		keyChar = [s characterAtIndex:0] ;
//		if (keyChar == 0x61) { // ASCII 0x61 = 'a'
//			[self selectAllIndexes] ;
//			didDo = YES ;
//		}
//	}

//	return didDo ;
//}
// EASY WAY:

- (IBAction)selectAll:(id)sender {
	[self selectAllIndexes] ;
}


// I'm not sure if this does any good for anything
- (BOOL)acceptsFirstResponder {
	return [self isEnabled] ;
}

- (void)changeSelectionPerMouseEvent:(NSEvent*)event {
	if ([self isEnabled]) {
		NSPoint pt = [self convertPoint:[event locationInWindow] fromView:nil] ;
		_mouseDownPoint = pt ;
		FramedToken* clickedFramedToken = [self tokenAtPoint:pt] ;
		int unsigned modifierFlags = [[NSApp currentEvent] modifierFlags] ;
		BOOL cmdKeyDown = ((modifierFlags & NSCommandKeyMask) != 0) ;
		if (clickedFramedToken) {
			[self changeSelectionPerUserActionAtFramedToken:clickedFramedToken] ;
		}
		else if (!cmdKeyDown) {
			[self deselectAllIndexes] ;
		}
		else {
			// cmdKeyDown but no token clicked
			// do nothing
		}
		
		[self sendAction:[self action]
					  to:[self target]] ;
	}
}

- (void)mouseDown:(NSEvent*)event {
	[[self window] makeFirstResponder:self] ;
	
	BOOL shiftOrCmdKeyDown = (([[NSApp currentEvent] modifierFlags] & (NSShiftKeyMask|NSCommandKeyMask)) != 0) ;
	// Following Apple's Safari Show All Bookmarks and Finder, we change
	// the selection on mouseDown if a modifier key is down, and on mouse
	// up if a modifier key is not down.  This allows drags to be
	// initiated immediately instead of requiring a wonky triple-click.
	if (shiftOrCmdKeyDown) {
		[self changeSelectionPerMouseEvent:event] ;
	}

	// Note that we do not invoke super.  If we do, then we do not 
	// get -mouseDragged: or -mouseDown:.
	// Alastair Houghton explains it thus:
	//    ...the default behaviour is probably to track the mouse until mouse up, but only if -enabled is YES.
	//    I can't say I've noticed this before myself, because I don't tend to forward -mouseDown: to super
	//     where super is a plain NSView.	
}

- (void)mouseUp:(NSEvent*)event {	
	BOOL shiftOrCmdKeyDown = (([[NSApp currentEvent] modifierFlags] & (NSShiftKeyMask|NSCommandKeyMask)) != 0) ;
	// Following Apple's Safari Show All Bookmarks and Finder, we change
	// the selection on mouseDown if a modifier key is down, and on mouse
	// up if a modifier key is not down.  This allows drags to be
	// initiated immediately instead of requiring a wonky triple-click.
	if (!shiftOrCmdKeyDown) {
		[self changeSelectionPerMouseEvent:event] ;
	}
}

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal {
	return NSDragOperationCopy ;
}

- (BOOL)pointHasOvercomeHysteresis:(NSPoint)point {
	float hysteresis = [self defaultFontSize]/2 ;
	if (fabs(point.y - _mouseDownPoint.y) > hysteresis) {
		return YES ;
	}
	if (fabs(point.x - _mouseDownPoint.x) > hysteresis) {
		return YES ;
	}
	
	return NO ;
}

- (void)mouseDragged:(NSEvent *)event {
	NSImage* dragImage = [self dragImage] ;
	if (dragImage) {
		NSPoint pt = [self convertPoint:[event locationInWindow] fromView:nil] ;
		if ([self pointHasOvercomeHysteresis:pt]) {
			NSArray* selectedTokens = [self selectedTokens] ;
			if ([selectedTokens count] > 0) {
				NSString* tabSeparatedTokens = [selectedTokens componentsJoinedByString:@"\t"] ;
				NSString* token1 = [selectedTokens objectAtIndex:0] ;
				NSPasteboard *pboard ;
				pboard = [NSPasteboard pasteboardWithName:NSDragPboard] ;
				[pboard declareTypes:[NSArray arrayWithObjects:
									  RPTokenPboardType,
									  RPTabularTokenPboardType,
									  NSStringPboardType,
									  NSTabularTextPboardType, nil]
							   owner:self] ;
				[pboard setString:token1
						  forType:RPTokenPboardType] ;
				[pboard setString:tabSeparatedTokens
						  forType:RPTabularTokenPboardType] ;
				[pboard setString:token1
						  forType:NSStringPboardType] ;
				[pboard setString:tabSeparatedTokens
						  forType:NSTabularTextPboardType] ;
				NSSize dragOffset = NSMakeSize(0.0, 0.0);
				
				[self dragImage:[self dragImage]
							 at:pt
						 offset:dragOffset
						  event:event
					 pasteboard:pboard
						 source:self
					  slideBack:YES];
			}
		}
	}
}

#pragma mark * Superclass Overrides (Basic Infrastructure)

// Because this NSControl does not have an NSActionCell, the
// following voodoo is needed to give it a cellClass.   Otherwise,
// its -setTarget and -setAction, or any such connection in 
// Interface Builder, will be ignored and -target and -action
// will always return nil.
+ (Class) cellClass {
    return [NSActionCell class];
}

- (NSString *)view:(NSView *)view
  stringForToolTip:(NSToolTipTag)token
			 point:(NSPoint)pos
		  userData:(void *)userData {
	NSString* answer ;
	FramedToken *framedToken = (FramedToken*)userData;
	int count = [framedToken count] ;
	if (count == 0) {
		// Wants toolTip for the special ellipsisToken
		NSString* key = _appendCountsToStrings ? @"textWithCountAppended" : @"text" ;
		NSArray* truncatedTokenStrings = [[self truncatedTokens] valueForKey:key] ;
		answer = [truncatedTokenStrings componentsJoinedByString:@"\n"] ;
	}
	else if (_showsCountsAsToolTips) {
		answer = [NSString stringWithFormat:@"%d", count] ;
	}
	else {
		// Return the regular view-wide toolTip, which is set by -setToolTip:
		answer =  [self toolTip] ;
	}
	
	return answer ;
}

- (id) initWithFrame:(NSRect)frame {
	self = [super initWithFrame:frame];
	if (self != nil) {
		[self setObjectValue:SSYNoTokensMarker] ;
		[self setSelectedIndexSet:[[NSMutableIndexSet alloc] init]] ;
		[self setEditable:YES] ;
		
		[self setMaxTokensToDisplay:NSNotFound] ;
		[self setMinFontSize:11.0] ;
		[self setMaxFontSize:40.0] ;
		[self setFixedFontSize:0.0] ;
		[self setShowsReflections:NO] ;
		[self setBackgroundWhiteness:1.0] ;
	}
	
	return self ;
}
- (void)dealloc {
	[_dragImage release] ;
	[_linkDragType release] ;
	[_tokenBeingEdited release] ;
	[m_disallowedCharacterSet release] ;
	[m_tokenizingCharacterSet release] ;
	[m_noTokensPlaceholder release] ;
	[m_noSelectionPlaceholder release] ;
	[m_multipleValuesPlaceholder release] ;
	[m_notApplicablePlaceholder release] ;
	[_selectedIndexSet release] ;
	[_textField release] ;
	[_framedTokens release] ;
	[_truncatedTokens release] ;
	[m_objectValue release] ;

	[super dealloc] ;
}

- (void)awakeFromNib {
	[self sendActionOn:NSLeftMouseDownMask] ;
	// We need to  that because the default for an NSControl
	// seems to be "left mouse UP".  We want DOWN.
	
	[self patchPreLeopardFocusRingDrawingForScrolling] ;
}

- (BOOL)isFlipped {
	// I believe that Robert decided to use a flipped y-coordinate because this
	// makes the -doLayout method easier, because you start laying in tokens from
	// the top.
	return YES ;
}

- (void)drawRect:(NSRect)rect {	
    if(_backgroundWhiteness < 1.0) {
        [[NSColor colorWithCalibratedWhite:_backgroundWhiteness alpha:1.0] set];
        NSRectFill(rect);
    }
   	
 	if ([_framedTokens count] > 0) {
		CGContextRef context = NULL;
        if(!_showsReflections) {
            context = [[NSGraphicsContext currentContext] graphicsPort];
            CGContextSaveGState(context);
            CGSize cgshOffset = {2.0, -2.0};
            CGContextSetShadow(context, cgshOffset, 1.0);
            CGContextBeginTransparencyLayer(context, NULL);
        }
        // Create attrDeselected, attributes for deselected tokens
		NSDictionary *attrDeselected = [NSDictionary dictionaryWithObjectsAndKeys:
										[NSColor whiteColor], TCFillColorAttributeName,
										nil] ;
		// Create attrSelected, attributes for selected tokens
		NSShadow *shadow = [[NSShadow alloc] init];
		[shadow setShadowOffset:NSMakeSize(2.0, -2.0)];
		[shadow setShadowBlurRadius:2.0];
		NSDictionary *attrSelected = [NSDictionary dictionaryWithObjectsAndKeys:
									  [NSColor whiteColor], NSForegroundColorAttributeName,
									  [NSColor selectedTextBackgroundColor], TCFillColorAttributeName,
									  shadow, NSShadowAttributeName,
									  nil] ;
		[shadow release];
        
		// Draw tokens that need to be drawn
        int i = 0 ;
		for (i=0; i<[_framedTokens count]; i++) {
			FramedToken *framedToken = [_framedTokens objectAtIndex:i] ;
			NSRect bounds = [framedToken bounds];
            if(!NSIntersectsRect(rect, bounds)) {
				// This framedToken is not in the rect to be drawn; move on to next one
				continue ;
			}
			else if (i == _indexOfFramedTokenBeingEdited) {
				// Don't draw the token if it is currently being obscured
				// by our _textField for editing.
				continue ;
			}
			if([self isSelectedFramedToken:framedToken]) {
				[framedToken drawWithAttributes:attrSelected
									appendCount:_appendCountsToStrings];
			}				
			else {
				[framedToken drawWithAttributes:attrDeselected
									appendCount:_appendCountsToStrings] ;
			}
			
            if(_showsReflections) {
				NSRect ref = NSMakeRect(bounds.origin.x+1, bounds.origin.y+1, bounds.size.width-3, bounds.size.height-3);
                ref.origin.y += 2 + ref.size.height;   
                if(NSIntersectsRect(rect, ref)) {
                    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:ref radius:ref.size.height*0.2];
                    [path shadow] ;  
                }
            }
        }
		
        if(context) {
            CGContextEndTransparencyLayer(context);
            CGContextRestoreGState(context);	
        }
	}
	else {
		NSString* string ;
		id value = [self objectValue] ;
		if ([value conformsToProtocol:@protocol(NSFastEnumeration)]) {
			// value is an empty collection.  That's OK.
			string = nil ;
		}
		else if (value == SSYNoTokensMarker) {
			string = [self noTokensPlaceholder] ;
		}
		else if (value == NSNoSelectionMarker) {
			string = [self noSelectionPlaceholder] ;
		}
		else if (value == NSMultipleValuesMarker) {
			string = [self multipleValuesPlaceholder] ;
		}
		else if (value == NSNotApplicableMarker) {
			string = [self notApplicablePlaceholder] ;
		}
		else {
			NSLog(@"Internal Error 189-1847 %@", value) ;
		}
		
		if (string != nil) {
			float fontSize = [self defaultFontSize] ;
			NSFont* font = [FramedToken fontOfSize:fontSize] ;
			float notUsed ;
			float whiteness = modff(_backgroundWhiteness + 0.5, &notUsed) ;
			NSColor* color = [NSColor colorWithCalibratedWhite:whiteness
														 alpha:1.0] ;
			NSDictionary* attributes = [NSDictionary dictionaryWithObjectsAndKeys:
										font, NSFontAttributeName,
										color, NSForegroundColorAttributeName,
										nil] ;
			NSAttributedString* attributedString = [[NSAttributedString alloc] initWithString:string
																				   attributes:attributes] ;
			NSRect rect = [self frame] ;
			rect.origin = NSMakePoint(fontSize * .25 + tokenBoxTextInset, tokenBoxTextInset) ;
			[attributedString drawInRect:rect] ;
			[attributedString release] ;
		}												
	}
	
	
	// Draw focus ring if we are firstResponder
	if ([[self window] firstResponder] == self) {
		[self drawFocusRing] ;
    }
}

#pragma mark * NSDraggingDestination Protocol Methods

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
    NSPasteboard* pboard = [sender draggingPasteboard] ;
	NSArray* types = [pboard types] ;
	NSDragOperation operation = NSDragOperationNone ;
	// Test this because registeredDraggedTypes is not supported in Mac OS 10.3
	if ([self respondsToSelector:@selector(registeredDraggedTypes)]) {
		NSString* linkDragType = [self linkDragType] ;
		BOOL tryDefaultTypes = YES ;
		if (linkDragType != nil) {
			if ([types containsObject:linkDragType]) {
				id delegate = [self delegate] ;
				if ([delegate respondsToSelector:@selector(draggingEntered:)]) {
					operation = [delegate draggingEntered:sender] ;
				}
				else {
					operation = NSDragOperationCopy ;
				}
				tryDefaultTypes = NO ;
			}
		}
		
		if (tryDefaultTypes) {
			NSEnumerator* e = [[self registeredDraggedTypes] objectEnumerator] ;
			NSString* type ;
			while ((type = [e nextObject])) {
				if ([types containsObject:type]) {
					operation = NSDragOperationCopy ;
					break ;
				}
			}
		}
	}
	
	return operation ;
}

- (BOOL)wantsPeriodicDraggingUpdates {
	// Updates every time the mouse moves will be sufficient.
	return NO ;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender {
	NSPoint locationInWindow = [sender draggingLocation] ;
	NSPoint locationInSelf = [self convertPoint:locationInWindow
									   fromView:nil] ;  // nil => convert from window coordinates
	FramedToken* token = [self tokenAtPoint:locationInSelf] ;
	if (token) {
		// Select, or extend selection
		[self changeSelectionPerUserActionAtFramedToken:token] ;
	}
	
	if ([[self selectedTokens] count] > 0) {
		id delegate = [self delegate] ;
		if ([delegate respondsToSelector:@selector(draggingUpdated:)]) {
			return [delegate draggingUpdated:sender] ;
		}
		else {
			return YES ;
		}
	}
	
    NSPasteboard* pboard = [sender draggingPasteboard] ;
	NSArray* types = [pboard types] ;
	NSDragOperation operation = NSDragOperationNone ;
	// Test this because registeredDraggedTypes is not supported in Mac OS 10.3
	if ([self respondsToSelector:@selector(registeredDraggedTypes)]) {
		NSString* linkDragType = [self linkDragType] ;
		BOOL tryDefaultTypes = YES ;
		if (linkDragType != nil) {
			if ([types containsObject:linkDragType]) {
				id delegate = [self delegate] ;
				if ([delegate respondsToSelector:@selector(draggingUpdated:)]) {
					operation = [delegate draggingUpdated:sender] ;
				}
				else {
					operation = NSDragOperationCopy ;
				}
				tryDefaultTypes = NO ;
			}
		}
		
		if (tryDefaultTypes) {
			NSEnumerator* e = [[self registeredDraggedTypes] objectEnumerator] ;
			NSString* type ;
			while ((type = [e nextObject])) {
				if ([types containsObject:type]) {
					operation = NSDragOperationCopy ;
					break ;
				}
			}
		}
	}
	
	return operation ;
}

- (BOOL)prepareForDragOperation:(id < NSDraggingInfo >)sender {
	// Since we would have previously cancelled the drag if we didn't
	// like it in draggingEntered, we simply
	return YES ;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
    NSPasteboard *pboard;
	
    pboard = [sender draggingPasteboard];
    BOOL ok = NO ;
	NSArray* newTokens = nil ;
	NSString* linkDragType = [self linkDragType] ;
	
	if ((linkDragType != nil) && ([[pboard types] containsObject:linkDragType])) {
		id delegate = [self delegate] ;
		if ([delegate respondsToSelector:@selector(performDragOperation:)]) {
			ok = [delegate performDragOperation:sender] ;
		}
		else {
			ok = NO ;
		}
	}
	else if ( [[pboard types] containsObject:NSTabularTextPboardType] ) {
        NSString* tokenString = [pboard stringForType:NSTabularTextPboardType] ;
		newTokens = [tokenString componentsSeparatedByString:@"\t"] ;
		ok = YES ;
    }
	else if ( [[pboard types] containsObject:NSStringPboardType] ) {
        NSString* newToken = [pboard stringForType:NSStringPboardType] ;
		newTokens = [NSArray arrayWithObject:newToken] ;
		ok = YES ;
    }
	
	if (newTokens != nil) {
		NSMutableSet* tokens = [[self tokensSet] mutableCopy] ;
		[tokens unionSet:[NSSet setWithArray:newTokens]] ;
		[self setObjectValue:tokens] ;
		[tokens release] ;
		ok = YES ;
	}		
	
    return ok ;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender {
	id delegate = [self delegate] ;
	if ([delegate respondsToSelector:@selector(draggingExited:)]) {
		[delegate draggingExited:sender] ;
	}
}

@end