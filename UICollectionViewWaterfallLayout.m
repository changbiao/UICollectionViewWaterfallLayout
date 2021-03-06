//
//  UICollectionViewWaterfallLayout.m
//
//  Created by Nelson on 12/11/19.
//  Copyright (c) 2012 Nelson Tai. All rights reserved.
//

#import "UICollectionViewWaterfallLayout.h"

static NSString *const WaterfallLayoutElementKindCell = @"WaterfallLayoutElementKindCell";

@interface UICollectionViewWaterfallLayout()
@property (nonatomic, assign) NSInteger itemCount;
@property (nonatomic, assign) CGFloat interitemSpacing;
@property (nonatomic, strong) NSMutableArray *columnHeights; // height for each column
@property (nonatomic, strong) NSDictionary *layoutInfo;
@end

@implementation UICollectionViewWaterfallLayoutAttributes

- (id)copyWithZone:(NSZone *)zone {
    UICollectionViewWaterfallLayoutAttributes *newAttributes = [super copyWithZone:zone];
    newAttributes.columnIndex = self.columnIndex;
    return newAttributes;
}

@end

@implementation UICollectionViewWaterfallLayout

+ (Class)layoutAttributesClass
{
    return [UICollectionViewWaterfallLayoutAttributes class];
}

#pragma mark - Accessors
- (void)setColumnCount:(NSUInteger)columnCount
{
    if (_columnCount != columnCount) {
        _columnCount = columnCount;
        [self invalidateLayout];
    }
}

- (void)setItemWidth:(CGFloat)itemWidth
{
    if (_itemWidth != itemWidth) {
        _itemWidth = itemWidth;
        [self invalidateLayout];
    }
}

- (void)setSectionInset:(UIEdgeInsets)sectionInset
{
    if (!UIEdgeInsetsEqualToEdgeInsets(_sectionInset, sectionInset)) {
        _sectionInset = sectionInset;
        [self invalidateLayout];
    }
}

- (void)setFooterHeight:(CGFloat)footerHeight {
    if (_footerHeight != footerHeight) {
        _footerHeight = footerHeight;
        [self invalidateLayout];
    }
}

- (void)setHeaderHeight:(CGFloat)headerHeight {
    if (_headerHeight != headerHeight) {
        _headerHeight = headerHeight;
        [self invalidateLayout];
    }
}

#pragma mark - Init
- (void)commonInit
{
    _columnCount = 2;
    _itemWidth = 140.0f;
    _sectionInset = UIEdgeInsetsZero;
    _headerHeight = 0.0f;
    _footerHeight = 0.0f;
}

- (id)init
{
    self = [super init];
    if (self) {
        [self commonInit];
    }
    return self;
}

#pragma mark - Life cycle
- (void)dealloc
{
    [_columnHeights removeAllObjects];
    _columnHeights = nil;

    _layoutInfo = nil;
}

#pragma mark - Methods to Override
- (void)prepareLayout
{
    [super prepareLayout];

    _itemCount = [[self collectionView] numberOfItemsInSection:0];
    NSUInteger sections = [self.collectionView numberOfSections];
    
    NSMutableDictionary *newLayoutInfo = [NSMutableDictionary dictionary];
    NSMutableDictionary *cellLayoutAttributes = [NSMutableDictionary dictionary];
    NSMutableDictionary *headerLayoutAttributes = [NSMutableDictionary dictionary];
    NSMutableDictionary *footerLayoutAttributes = [NSMutableDictionary dictionary];

    NSAssert(_columnCount > 1, @"columnCount for UICollectionViewWaterfallLayout should be greater than 1.");
    CGFloat width = self.collectionView.frame.size.width - _sectionInset.left - _sectionInset.right;
    _interitemSpacing = floorf((width - _columnCount * _itemWidth) / (_columnCount - 1));

    _columnHeights = [NSMutableArray arrayWithCapacity:_columnCount];
    for (NSInteger idx = 0; idx < _columnCount; idx++) {
        [_columnHeights addObject:@(_sectionInset.top)];
    }

	// layout the header
	NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:0];
	if (_headerHeight > 0) {
		UICollectionViewLayoutAttributes *headerAttributes = [UICollectionViewLayoutAttributes layoutAttributesForSupplementaryViewOfKind:UICollectionElementKindSectionHeader withIndexPath:indexPath];
		
		headerAttributes.frame = (CGRect) {
			0.0,
			0.0,
			self.collectionViewContentSize.width,
			_headerHeight
		};
		headerLayoutAttributes[indexPath] = headerAttributes;
	}

    // Item will be put into shortest column.
    for (NSInteger idx = 0; idx < _itemCount; idx++) {
        indexPath = [NSIndexPath indexPathForItem:idx inSection:0];
        CGFloat itemHeight = [self.delegate collectionView:self.collectionView
                                                    layout:self
                                  heightForItemAtIndexPath:indexPath];
        NSUInteger columnIndex = [self shortestColumnIndex];
        CGFloat xOffset = _sectionInset.left + (_itemWidth + _interitemSpacing) * columnIndex;

        CGFloat yOffset = [(_columnHeights[columnIndex]) floatValue];
        if (indexPath.item < _columnCount) {
            yOffset += _headerHeight;
        }
        
        UICollectionViewWaterfallLayoutAttributes *attributes = [UICollectionViewWaterfallLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
        
        attributes.frame = CGRectMake(xOffset, (sections == 2 && _itemCount == 1) ? 0.0 : yOffset, (sections == 2 && _itemCount == 1) ? self.collectionViewContentSize.width : self.itemWidth, itemHeight);
        attributes.columnIndex = columnIndex;
        
        cellLayoutAttributes[indexPath] = attributes;
        _columnHeights[columnIndex] = @(yOffset + itemHeight + _interitemSpacing);

        
    }
	// layout the footer
	if (_footerHeight > 0.0) {
		UICollectionViewLayoutAttributes *footerAttributes = [UICollectionViewLayoutAttributes layoutAttributesForSupplementaryViewOfKind:UICollectionElementKindSectionFooter withIndexPath:indexPath];
		
		footerAttributes.frame = (CGRect) {
			0.0,
			self.collectionViewContentSize.height - _footerHeight,
			self.collectionViewContentSize.width,
			_footerHeight
		};
		footerLayoutAttributes[indexPath] = footerAttributes;
	}
    
    newLayoutInfo[WaterfallLayoutElementKindCell] = cellLayoutAttributes;
    newLayoutInfo[UICollectionElementKindSectionHeader] = headerLayoutAttributes;
    newLayoutInfo[UICollectionElementKindSectionFooter] = footerLayoutAttributes;
    
    _layoutInfo = newLayoutInfo;
}

- (CGSize)collectionViewContentSize
{
    CGSize contentSize = self.collectionView.frame.size;
    
	if (self.itemCount == 0) {
		contentSize.height = self.sectionInset.top + _headerHeight + _footerHeight + self.sectionInset.bottom;
        return contentSize;
    }

    NSUInteger columnIndex = [self longestColumnIndex];
    CGFloat height = [self.columnHeights[columnIndex] floatValue];
    contentSize.height = self.sectionInset.top + _headerHeight + height - self.interitemSpacing + _footerHeight + self.sectionInset.bottom;
    return contentSize;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)path
{
    return _layoutInfo[WaterfallLayoutElementKindCell][path];
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForSupplementaryViewOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    
    UICollectionViewLayoutAttributes *layoutAttributes = nil;
    
    if (kind == UICollectionElementKindSectionHeader) {
        layoutAttributes = _layoutInfo[UICollectionElementKindSectionHeader][indexPath];
    } else if (kind == UICollectionElementKindSectionFooter) {
        layoutAttributes = _layoutInfo[UICollectionElementKindSectionFooter][indexPath];
    }
    
    return layoutAttributes;
}

- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect
{
    NSMutableArray *allAttributes = [NSMutableArray arrayWithCapacity:self.layoutInfo.count];
    
    [self.layoutInfo enumerateKeysAndObjectsUsingBlock:^(NSString *elementIdentifier, NSDictionary *elementsInfo, BOOL *stop) {
        [elementsInfo enumerateKeysAndObjectsUsingBlock:^(NSIndexPath *indexPath, UICollectionViewLayoutAttributes *attributes, BOOL *innerStop) {
            if (CGRectIntersectsRect(rect, attributes.frame)) {
                [allAttributes addObject:attributes];
            }
        }];
    }];
    
    return allAttributes;
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds
{
    return NO;
}

#pragma mark - Private Methods
// Find out shortest column.
- (NSUInteger)shortestColumnIndex
{
    __block NSUInteger index = 0;
    __block CGFloat shortestHeight = MAXFLOAT;

    [self.columnHeights enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        CGFloat height = [obj floatValue];
        if (height < shortestHeight) {
            shortestHeight = height;
            index = idx;
        }
    }];

    return index;
}

// Find out longest column.
- (NSUInteger)longestColumnIndex
{
    __block NSUInteger index = 0;
    __block CGFloat longestHeight = 0;

    [self.columnHeights enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        CGFloat height = [obj floatValue];
        if (height > longestHeight) {
            longestHeight = height;
            index = idx;
        }
    }];

    return index;
}

@end
