import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';
import 'package:mightystore/component/HtmlWidget.dart';
import 'package:mightystore/component/VideoPlayDialog.dart';
import 'package:mightystore/main.dart';
import 'package:mightystore/models/ProductDetailResponse.dart';
import 'package:mightystore/models/ProductReviewModel.dart';
import 'package:mightystore/network/rest_apis.dart';
import 'package:mightystore/screen/ProductDetail/ProductDetailScreen2.dart';
import 'package:mightystore/screen/ViewAllScreen.dart';
import 'package:mightystore/screen/ZoomImageScreen.dart';
import 'package:mightystore/utils/AppBarWidget.dart';
import 'package:mightystore/utils/Countdown.dart';
import 'package:mightystore/utils/admob_utils.dart';
import 'package:mightystore/utils/app_Widget.dart';
import 'package:mightystore/utils/colors.dart';
import 'package:mightystore/utils/common.dart';
import 'package:mightystore/utils/constants.dart';
import 'package:nb_utils/nb_utils.dart';
import '../../app_localizations.dart';
import '../ReviewScreen.dart';
import '../SignInScreen.dart';
import '../VendorProfileScreen.dart';
import '../WebViewExternalProductScreen.dart';
import 'ProductDetailScreen3.dart';

class ProductDetailScreen1 extends StatefulWidget {
  final int? mProId;

  ProductDetailScreen1({Key? key, this.mProId}) : super(key: key);

  @override
  _ProductDetailScreen1State createState() => _ProductDetailScreen1State();
}

class _ProductDetailScreen1State extends State<ProductDetailScreen1> {
  ProductDetailResponse? productDetailNew;

  List<ProductDetailResponse> mProducts = [];
  List<ProductReviewModel> mReviewModel = [];
  List<ProductDetailResponse> mProductsList = [];
  List<String?> mProductOptions = [];
  List<int> mProductVariationsIds = [];
  List<ProductDetailResponse> product = [];
  List<Widget> productImg = [];
  List<String?> productImg1 = [];

  InterstitialAd? interstitialAd;
  GlobalKey<ScaffoldState> scaffoldState = GlobalKey();
  PageController _pageController = PageController(initialPage: 0);

  bool mIsExternalProduct = false;

  num rating = 0.0;
  double discount = 0.0;

  int selectIndex = 0;
  int _currentPage = 0;

  String videoType = '';
  String? mSelectedVariation = '';
  String mExternalUrl = '';

  @override
  void initState() {
    super.initState();
    init();
  }

  setTimer() {
    Timer.periodic(Duration(seconds: 10), (Timer timer) {
      if (_currentPage < 2) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: Duration(milliseconds: 350),
          curve: Curves.easeIn,
        );
      }
    });
  }

  init() async {
    afterBuildCreated(() {
      adShow();
      productDetail();
      fetchReviewData();
      setTimer();
    });
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  adShow() async {
    if (interstitialAd == null) {
      print('Warning: attempt to show interstitial before loaded.');
      return;
    }
    interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (InterstitialAd ad) => print('ad onAdShowedFullScreenContent.'),
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        print('$ad onAdDismissedFullScreenContent.');
        ad.dispose();
        _createInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        print('$ad onAdFailedToShowFullScreenContent: $error');
        ad.dispose();
        _createInterstitialAd();
      },
    );
    enableAds ? interstitialAd!.show() : SizedBox();
  }

  void _createInterstitialAd() {
    InterstitialAd.load(
        adUnitId: kReleaseMode ? getInterstitialAdUnitId()! : InterstitialAd.testAdUnitId,
        request: AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (InterstitialAd ad) {
            print('$ad loaded');
            interstitialAd = ad;
          },
          onAdFailedToLoad: (LoadAdError error) {
            print('InterstitialAd failed to load: $error.');
            interstitialAd = null;
          },
        ));
  }

  @override
  Future<void> dispose() async {
    _pageController.dispose();
    super.dispose();
  }

  Future productDetail() async {
    await getProductDetail(widget.mProId).then((res) {
      if (!mounted) return;
      setState(() {
        appStore.setLoading(false);
        Iterable mInfo = res;
        mProducts = mInfo.map((model) => ProductDetailResponse.fromJson(model)).toList();

        if (mProducts.isNotEmpty) {
          productDetailNew = mProducts[0];
          rating = double.parse(mProducts[0].averageRating!);
          productDetailNew!.variations!.forEach((element) {
            mProductVariationsIds.add(element);
          });
          mProductsList.clear();

          for (var i = 0; i < mProducts.length; i++) {
            if (i != 0) {
              mProductsList.add(mProducts[i]);
            }
          }

          if (productDetailNew!.type == "variable" || productDetailNew!.type == "variation") {
            mProductOptions.clear();
            mProductsList.forEach((product) {
              var option = '';

              product.attributes!.forEach((attribute) {
                if (option.isNotEmpty) {
                  option = '$option - ${attribute.option.validate()}';
                } else {
                  option = attribute.option.validate();
                }
              });

              if (product.onSale!) {
                option = '$option [Sale]';
              }

              mProductOptions.add(option);
            });
            if (mProductOptions.isNotEmpty) mSelectedVariation = mProductOptions.first;

            if (productDetailNew!.type == "variable" || productDetailNew!.type == "variation" && mProductsList.isNotEmpty) {
              productDetailNew = mProductsList[0];
              mProducts = mProducts;
            }
            log('mProductOptions');
          } else if (productDetailNew!.type == 'grouped') {
            product.clear();
            product.addAll(mProductsList);
          }

          if (productDetailNew!.woofVideoEmbed != null) {
            if (productDetailNew!.woofVideoEmbed!.url != '') {
              if (productDetailNew!.woofVideoEmbed!.url.validate().contains(VideoTypeYouTube)) {
                videoType = VideoTypeYouTube;
              } else if (productDetailNew!.woofVideoEmbed!.url.validate().contains(VideoTypeIFrame)) {
                videoType = VideoTypeIFrame;
              } else {
                videoType = VideoTypeCustom;
              }
              productImg.add(
                Stack(
                  fit: StackFit.expand,
                  children: [
                    commonCacheImageWidget(
                      productDetailNew!.images![0].src.validate(),
                      fit: BoxFit.cover,
                      height: 400,
                      width: double.infinity,
                    ).cornerRadiusWithClipRRectOnly(topLeft: 20, topRight: 20).paddingOnly(bottom: 24),
                    Icon(Icons.play_circle_fill_outlined, size: 40, color: Colors.black12).center(),
                  ],
                ).onTap(() {
                  VideoPlayDialog(data: productDetailNew!.woofVideoEmbed).launch(context);
                }),
              );
            }
          }
          mImage();
          setPriceDetail();
        }
      });
    }).catchError((error) {
      log('error:$error');
      appStore.setLoading(false);
      toast(error.toString());
    });
  }

  Future fetchReviewData() async {
    appStore.setLoading(true);
    await getProductReviews(widget.mProId).then((res) {
      appStore.setLoading(false);
      setState(() {
        Iterable list = res;
        mReviewModel = list.map((model) => ProductReviewModel.fromJson(model)).toList();
      });
    }).catchError((error) {
      appStore.setLoading(false);
    });
  }

// Set Price Detail
  Widget setPriceDetail() {
    setState(() {
      if (productDetailNew!.onSale!) {
        double mrp = double.parse(productDetailNew!.regularPrice!).toDouble();
        double discountPrice = double.parse(productDetailNew!.price!).toDouble();
        discount = ((mrp - discountPrice) / mrp) * 100;
      }
    });
    return SizedBox();
  }

  void mImage() {
    setState(() {
      productImg1.clear();
      productDetailNew!.images!.forEach((element) {
        productImg1.add(element.src);
      });
    });
  }

  Widget mDiscount() {
    if (productDetailNew!.onSale!)
      return Container(
        child: Text(
          "(" + '${discount.toInt()} % ${AppLocalizations.of(context)!.translate('lbl_off1')! + ")"}',
          style: primaryTextStyle(color: Colors.red),
        ),
      );
    else
      return SizedBox();
  }

  Widget mSpecialPrice(String? value) {
    if (productDetailNew != null) {
      if (productDetailNew!.dateOnSaleFrom != "") {
        var endTime = productDetailNew!.dateOnSaleTo.toString() + " 23:59:59.000";
        var endDate = DateFormat('yyyy-MM-dd HH:mm:ss').parse(endTime);
        var currentDate = DateFormat('yyyy-MM-dd HH:mm:ss').parse(DateTime.now().toString());
        var format = endDate.subtract(Duration(days: currentDate.day, hours: currentDate.hour, minutes: currentDate.minute, seconds: currentDate.second));
        log(format);

        return Countdown(
          duration: Duration(days: format.day, hours: format.hour, minutes: format.minute, seconds: format.second),
          onFinish: () {
            log('finished!');
          },
          builder: (BuildContext ctx, Duration? remaining) {
            var seconds = ((remaining!.inMilliseconds / 1000) % 60).toInt();
            var minutes = (((remaining.inMilliseconds / (1000 * 60)) % 60)).toInt();
            var hours = (((remaining.inMilliseconds / (1000 * 60 * 60)) % 24)).toInt();
            log(hours);
            return Container(
              decoration: boxDecorationWithRoundedCorners(borderRadius: radius(4), backgroundColor: colorAccent!.withOpacity(0.3)),
              child: Text(
                value! + " " + '${remaining.inDays}d ${hours}h ${minutes}m ${seconds}s',
                style: primaryTextStyle(),
              ).paddingAll(8),
            ).paddingOnly(left: 16, right: 16, top: 16, bottom: 16);
          },
        );
      } else {
        return SizedBox();
      }
    } else {
      return SizedBox();
    }
  }

  String getAllAttribute(Attribute attribute) {
    String attributes = "";
    for (var i = 0; i < attribute.options!.length; i++) {
      attributes = attributes + attribute.options![i];
      if (i < attribute.options!.length - 1) {
        attributes = attributes + ", ";
      }
    }
    return attributes;
  }

// Set additional information
  Widget mSetAttribute() {
    return ListView.builder(
      itemCount: productDetailNew!.attributes!.length,
      padding: EdgeInsets.only(left: 8, right: 8, top: 8),
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      scrollDirection: Axis.vertical,
      itemBuilder: (context, i) {
        return productDetailNew!.attributes![i].options != null
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(productDetailNew!.attributes![i].name + " : ", style: boldTextStyle(size: 14)).visible(productDetailNew!.attributes![i].options!.isNotEmpty),
                  4.height,
                  Text(getAllAttribute(productDetailNew!.attributes![i]), maxLines: 4, style: secondaryTextStyle()).expand(),
                ],
              ).paddingOnly(left: 8)
            : SizedBox();
      },
    );
  }

// ignore: missing_return
  mOtherAttribute() {
    toast('Product type not supported');
    finish(context);
  }

  @override
  Widget build(BuildContext context) {
    setValue(CARTCOUNT, appStore.count);

    var appLocalization = AppLocalizations.of(context);

    Widget mUpcomingSale() {
      if (productDetailNew != null) {
        if (productDetailNew!.dateOnSaleFrom != "") {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Divider(thickness: 6, color: appStore.isDarkMode! ? white.withOpacity(0.2) : Theme.of(context).textTheme.headline4!.color),
              Text(appLocalization!.translate('lbl_upcoming_sale_on_this_item')!, style: boldTextStyle()).paddingAll(16),
              Container(
                margin: EdgeInsets.only(left: 16, right: 16, bottom: 10),
                decoration: boxDecorationWithRoundedCorners(borderRadius: radius(8), backgroundColor: primaryColor!.withOpacity(0.2)),
                width: context.width(),
                padding: EdgeInsets.fromLTRB(2, 8, 2, 8),
                child: Marquee(
                  directionMarguee: DirectionMarguee.oneDirection,
                  child: Text(
                    appLocalization.translate('lbl_sale_start_from')! +
                        " " +
                        productDetailNew!.dateOnSaleFrom! +
                        " " +
                        appLocalization.translate('lbl_to')! +
                        " " +
                        productDetailNew!.dateOnSaleTo! +
                        ". " +
                        appLocalization.translate('lbl_ge_amazing_discounts_on_the_products')!,
                    style: secondaryTextStyle(color: Theme.of(context).textTheme.subtitle2!.color, size: 16),
                  ).paddingLeft(16),
                ),
              ),
            ],
          );
        } else {
          return SizedBox();
        }
      } else {
        return SizedBox();
      }
    }

    Widget _review() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(appLocalization!.translate("lbl_customer_review")!, style: boldTextStyle()).paddingOnly(top: 8, bottom: 8, left: 16, right: 16).visible(mReviewModel.isNotEmpty),
          ListView.separated(
              separatorBuilder: (context, index) {
                return Divider();
              },
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: mReviewModel.length >= 5 ? 5 : mReviewModel.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.only(left: 6, right: 6, top: 2, bottom: 2),
                        decoration: BoxDecoration(
                            color: mReviewModel[index].rating == 1
                                ? redColor
                                : mReviewModel[index].rating == 2
                                    ? yellowColor
                                    : mReviewModel[index].rating == 3
                                        ? yellowColor
                                        : Color(0xFF66953A),
                            borderRadius: BorderRadius.all(Radius.circular(8))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Text(mReviewModel[index].rating.toString(), style: primaryTextStyle(color: whiteColor, size: 12)),
                            4.width,
                            Icon(Icons.star_border, size: 14, color: whiteColor)
                          ],
                        ),
                      ),
                      8.width,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(mReviewModel[index].reviewer!, style: boldTextStyle()),
                              Container(
                                height: 10,
                                color: Theme.of(context).textTheme.subtitle1!.color,
                                width: 2,
                                margin: EdgeInsets.only(left: 8, right: 8),
                              ),
                              Text(reviewConvertDate(mReviewModel[index].dateCreated), style: secondaryTextStyle()),
                            ],
                          ).visible(mReviewModel[index].reviewer != null),
                          5.height,
                          Text(parseHtmlString(mReviewModel[index].review), style: primaryTextStyle()),
                        ],
                      ).expand(),
                    ],
                  ),
                );
              }),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(appLocalization.translate("lbl_view_all_customer_review")!, style: boldTextStyle(color: context.accentColor)),
              Icon(Icons.chevron_right),
            ],
          )
              .onTap(() {
                ReviewScreen(mProductId: productDetailNew!.id).launch(context);
              })
              .paddingAll(16)
              .visible(mReviewModel.length >= 5 && productDetailNew!.reviewsAllowed == true),
        ],
      );
    }

    Widget upSaleProductList(List<UpsellId> product) {
      var productWidth = MediaQuery.of(context).size.width;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          8.height,
          Text(builderResponse.dashboard!.youMayLikeProduct!.title!, style: boldTextStyle()).paddingLeft(16),
          Container(
            margin: EdgeInsets.only(top: 8, bottom: 16),
            height: 233,
            child: ListView.builder(
              itemCount: product.length,
              shrinkWrap: true,
              padding: EdgeInsets.only(left: 8),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, i) {
                return Container(
                  width: 160,
                  margin: EdgeInsets.only(left: 8, right: 8, top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        decoration: boxDecorationWithRoundedCorners(borderRadius: radius(8), backgroundColor: Theme.of(context).colorScheme.background),
                        child: Stack(
                          children: [
                            commonCacheImageWidget(product[i].images!.first.src, height: 150, width: productWidth, fit: BoxFit.cover).cornerRadiusWithClipRRect(8),
                          ],
                        ),
                      ),
                      4.height,
                      Text(product[i].name!, style: primaryTextStyle(size: 14), maxLines: 2),
                      8.height,
                      Row(
                        children: [
                          PriceWidget(price: product[i].salePrice.toString().isNotEmpty ? product[i].salePrice.toString() : product[i].price.toString(), size: 14, color: primaryColor),
                          4.width,
                          PriceWidget(price: product[i].regularPrice.toString(), size: 12, isLineThroughEnabled: true, color: Theme.of(context).textTheme.subtitle2!.color)
                              .visible(product[i].salePrice.toString().isNotEmpty),
                        ],
                      ),
                    ],
                  ),
                ).onTap(() {
                  if (getIntAsync(PRODUCT_DETAIL_VARIANT, defaultValue: 1) == 1) {
                    ProductDetailScreen1(mProId: product[i].id).launch(context);
                  } else if (getIntAsync(PRODUCT_DETAIL_VARIANT, defaultValue: 1) == 2) {
                    ProductDetailScreen2(mProId: product[i].id).launch(context);
                  } else if (getIntAsync(PRODUCT_DETAIL_VARIANT, defaultValue: 1) == 3) {
                    ProductDetailScreen3(mProId: product[i].id).launch(context);
                  } else {
                    ProductDetailScreen1(mProId: product[i].id).launch(context);
                  }
                });
              },
            ),
          )
        ],
      );
    }

    Widget mGroupAttribute(List<ProductDetailResponse> product) {
      return Observer(builder: (context) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Divider(thickness: 6, color: appStore.isDarkMode! ? white.withOpacity(0.2) : Theme.of(context).textTheme.headline4!.color),
            Text(appLocalization!.translate('lbl_product_include')!, style: boldTextStyle()).paddingOnly(left: 16, top: 8),
            ListView.builder(
              physics: NeverScrollableScrollPhysics(),
              scrollDirection: Axis.vertical,
              shrinkWrap: true,
              itemCount: product.length,
              padding: EdgeInsets.only(left: 16, right: 16),
              itemBuilder: (context, i) {
                return GestureDetector(
                  onTap: () {
                    if (getIntAsync(PRODUCT_DETAIL_VARIANT, defaultValue: 1) == 1) {
                      ProductDetailScreen1(mProId: product[i].id).launch(context);
                    } else if (getIntAsync(PRODUCT_DETAIL_VARIANT, defaultValue: 1) == 2) {
                      ProductDetailScreen2(mProId: product[i].id).launch(context);
                    } else if (getIntAsync(PRODUCT_DETAIL_VARIANT, defaultValue: 1) == 3) {
                      ProductDetailScreen3(mProId: product[i].id).launch(context);
                    } else {
                      ProductDetailScreen1(mProId: product[i].id).launch(context);
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.only(right: 8, bottom: 8, top: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        commonCacheImageWidget(product[i].images![0].src, height: 85, width: 85, fit: BoxFit.cover).cornerRadiusWithClipRRect(8),
                        4.width,
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(product[i].name!, style: boldTextStyle()).paddingOnly(left: 8, right: 8),
                            16.height,
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(10),
                                  decoration: boxDecorationWithRoundedCorners(
                                      borderRadius: radius(8), backgroundColor: product[i].inStock == true ? primaryColor! : white, border: Border.all(color: primaryColor!)),
                                  child: Text(
                                    productDetailNew!.inStock! == true
                                        ? productDetailNew!.type! == 'external'
                                            ? productDetailNew!.buttonText!
                                            : cartStore.isItemInCart(product[i].id.validate())
                                                ? appLocalization.translate('lbl_remove_cart')!.toUpperCase()
                                                : appLocalization.translate('lbl_add_to_cart')!.toUpperCase()
                                        : appLocalization.translate('lbl_sold_out')!.toUpperCase(),
                                    textAlign: TextAlign.center,
                                    style: boldTextStyle(color: product[i].inStock == false ? primaryColor : white, size: 12),
                                  ),
                                ).onTap(() {
                                  if (product[i].inStock == true) {
                                    if (product[i].type == 'external') {
                                      WebViewExternalProductScreen(mExternal_URL: mExternalUrl, title: appLocalization.translate('lbl_external_product')).launch(context);
                                    } else if (!getBoolAsync(IS_LOGGED_IN)) {
                                      SignInScreen().launch(context, pageRouteAnimation: PageRouteAnimation.Slide);
                                    } else {
                                      addCart(data: product[i]);

                                      init();
                                      setState(() {});
                                    }
                                  }
                                }),
                                Row(
                                  children: [
                                    PriceWidget(
                                        price: product[i].salePrice.toString().validate().isNotEmpty ? product[i].salePrice.toString() : product[i].price.toString().validate(),
                                        size: 16,
                                        color: primaryColor),
                                    2.width,
                                    PriceWidget(price: product[i].regularPrice.toString(), size: 12, isLineThroughEnabled: true, color: Theme.of(context).textTheme.subtitle2!.color)
                                        .visible(product[i].salePrice.toString().isNotEmpty),
                                  ],
                                )
                              ],
                            ).paddingOnly(left: 8),
                          ],
                        ).expand()
                      ],
                    ),
                  ),
                );
              },
            )
          ],
        );
      });
    }

    final videoSlider = productDetailNew != null
        ? Container(
            height: 450,
            width: MediaQuery.of(context).size.width,
            decoration: boxDecorationWithRoundedCorners(
                borderRadius: BorderRadius.only(topRight: Radius.circular(20), topLeft: Radius.circular(20)), backgroundColor: Theme.of(context).scaffoldBackgroundColor),
            child: Stack(
              children: [
                PageView(
                    children: productImg,
                    controller: _pageController,
                    onPageChanged: (index) {
                      selectIndex = index;
                      setState(() {});
                    }),
                AnimatedPositioned(
                  duration: Duration(seconds: 1),
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: DotIndicator(pages: productImg, indicatorColor: primaryColor, pageController: _pageController),
                ),
              ],
            ),
          )
        : SizedBox();

    final imgSlider = productDetailNew != null
        ? Container(
            height: 450,
            width: MediaQuery.of(context).size.width,
            decoration: boxDecorationWithRoundedCorners(borderRadius: BorderRadius.only(topRight: Radius.circular(20), topLeft: Radius.circular(20)), backgroundColor: context.cardColor),
            margin: EdgeInsets.only(bottom: 16),
            child: Stack(
              children: [
                PageView(
                  children: productImg1.map((i) {
                    return commonCacheImageWidget(i.validate(), fit: BoxFit.cover, height: 400, width: double.infinity)
                        .cornerRadiusWithClipRRectOnly(topLeft: 20, topRight: 20)
                        .paddingOnly(bottom: 24)
                        .onTap(() {
                      ZoomImageScreen(mImgList: productDetailNew!.images, ind: selectIndex).launch(context);
                    });
                  }).toList(),
                  controller: _pageController,
                  onPageChanged: (index) {
                    selectIndex = index;
                    setState(() {});
                  },
                ),
                AnimatedPositioned(
                    duration: Duration(seconds: 1), bottom: 0, left: 0, right: 0, child: DotIndicator(pages: productImg1, indicatorColor: primaryColor, pageController: _pageController)),
              ],
            ),
          )
        : SizedBox();

    // Check Wish list
    final mFavourite = productDetailNew != null
        ? Observer(builder: (context) {
            return GestureDetector(
              onTap: () {
                if (productDetailNew!.type! == 'external') {
                  toast(appLocalization!.translate('lbl_external_wishlist_msg')!);
                } else {
                  checkWishList(productDetailNew, context);
                  setState(() {});
                }
              },
              child: Container(
                padding: EdgeInsets.all(10),
                decoration: boxDecorationWithRoundedCorners(borderRadius: radius(8), backgroundColor: Theme.of(context).cardTheme.color!, border: Border.all(color: primaryColor!)),
                child: Text(
                    wishListStore.isItemInWishlist(productDetailNew!.id!) == false
                        ? appLocalization!.translate('lbl_wish_list')!.toUpperCase()
                        : appLocalization!.translate('lbl_wishlisted')!.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: boldTextStyle(color: primaryColor, wordSpacing: 2)),
              ),
            ).paddingOnly(bottom: 4).visible(productDetailNew!.isAddedWishList != null);
          })
        : SizedBox();

    final mCartData = productDetailNew != null
        ? GestureDetector(
            onTap: () {
              if (productDetailNew!.inStock == true) {
                if (mIsExternalProduct) {
                  WebViewExternalProductScreen(mExternal_URL: mExternalUrl, title: appLocalization!.translate('lbl_external_product')).launch(context);
                } else if (!getBoolAsync(IS_LOGGED_IN)) {
                  SignInScreen().launch(context, pageRouteAnimation: PageRouteAnimation.Slide);
                } else {
                  addCart(data: productDetailNew!);
                  init();
                  setState(() {});
                }
              }
              setState(() {});
            },
            child: Container(
              padding: EdgeInsets.all(10),
              decoration: boxDecorationWithRoundedCorners(borderRadius: radius(8), backgroundColor: productDetailNew!.inStock! ? primaryColor! : textSecondaryColorGlobal.withOpacity(0.3)),
              child: Text(
                productDetailNew!.inStock! == true
                    ? productDetailNew!.type! == 'external'
                        ? productDetailNew!.buttonText!
                        : cartStore.isItemInCart(productDetailNew!.id.validate())
                            ? appLocalization!.translate('lbl_remove_cart')!.toUpperCase()
                            : appLocalization!.translate('lbl_add_to_cart')!.toUpperCase()
                    : appLocalization!.translate('lbl_sold_out')!.toUpperCase(),
                textAlign: TextAlign.center,
                style: boldTextStyle(color: white, wordSpacing: 2),
              ),
            ),
          )
        : SizedBox();

    final mPrice = productDetailNew != null
        ? productDetailNew!.onSale == true
            ? Row(
                children: [
                  PriceWidget(
                      price: productDetailNew!.salePrice.toString().isNotEmpty
                          ? double.parse(productDetailNew!.salePrice.toString()).toStringAsFixed(2)
                          : double.parse(productDetailNew!.price.validate().toString()).toStringAsFixed(2),
                      size: 18,
                      color: primaryColor),
                  PriceWidget(
                          price: double.parse(productDetailNew!.regularPrice.toString()).toStringAsFixed(2), size: 14, color: Theme.of(context).textTheme.subtitle1!.color, isLineThroughEnabled: true)
                      .visible(productDetailNew!.salePrice.toString().isNotEmpty && productDetailNew!.onSale == true),
                  8.width,
                  mDiscount().visible(productDetailNew!.salePrice.toString().isNotEmpty && productDetailNew!.onSale == true)
                ],
              )
            : Row(
                children: [
                  PriceWidget(price: double.parse(productDetailNew!.price.toString()).toStringAsFixed(2), size: 18, color: primaryColor),
                ],
              )
        : SizedBox();

    Widget mSavePrice() {
      if (productDetailNew != null) {
        if (productDetailNew!.onSale!) {
          var value = double.parse(productDetailNew!.regularPrice.toString()) - double.parse(productDetailNew!.price.toString());
          if (value > 0) {
            return Row(
              children: [
                Text(appLocalization!.translate('lbl_you_saved')! + " ", style: secondaryTextStyle(size: 16, color: Colors.green)),
                PriceWidget(price: value.toStringAsFixed(2), size: 18, color: Colors.green)
              ],
            ).paddingOnly(top: 4, left: 16, right: 8);
          } else {
            return SizedBox();
          }
        } else {
          return SizedBox();
        }
      } else {
        return SizedBox();
      }
    }

    Widget mExternalAttribute() {
      setPriceDetail();
      mIsExternalProduct = true;
      mExternalUrl = productDetailNew!.externalUrl.toString();
      return SizedBox();
    }

    final body = productDetailNew != null
        ? SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                productDetailNew!.images!.isNotEmpty
                    ? productDetailNew!.woofVideoEmbed != null && productDetailNew!.woofVideoEmbed!.url != ''
                        ? videoSlider
                        : imgSlider
                    : SizedBox(),
                Container(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      8.height,
                      if (productDetailNew!.onSale == true)
                        FittedBox(
                          child: Container(
                            padding: EdgeInsets.fromLTRB(6, 2, 6, 2),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.all(Radius.circular(4))),
                            child: Text(appLocalization!.translate('lbl_sale')!, style: boldTextStyle(color: Colors.white, size: 12)),
                          ).cornerRadiusWithClipRRectOnly(topLeft: 0, bottomLeft: 4).paddingOnly(left: 16, right: 16, bottom: 8),
                        ),
                      Text(productDetailNew!.name!, style: boldTextStyle(size: 18)).paddingOnly(left: 16, right: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          mPrice,
                          FittedBox(
                            child: Container(
                              decoration: boxDecorationWithRoundedCorners(borderRadius: radius(4), backgroundColor: Theme.of(context).cardTheme.color!, border: Border.all(color: view_color)),
                              padding: EdgeInsets.fromLTRB(4, 4, 4, 4),
                              margin: EdgeInsets.only(right: 8),
                              child: RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(text: rating.toString() + " ", style: secondaryTextStyle(size: 14)),
                                    WidgetSpan(child: Icon(Icons.star, size: 14, color: yellowColor)),
                                  ],
                                ),
                              ),
                            ),
                          ).onTap(() async {
                            final bool result = await ReviewScreen(mProductId: productDetailNew!.id).launch(context);
                            if (result == true) {
                              init();
                              setState(() {});
                            }
                          })
                        ],
                      ).paddingOnly(top: 4, left: 16, right: 8, bottom: 4).visible(!productDetailNew!.type!.contains("grouped")),
                      mSavePrice().visible(!productDetailNew!.type!.contains("grouped")),
                      if (productDetailNew!.store != null)
                        Divider(thickness: 6, color: appStore.isDarkMode! ? white.withOpacity(0.2) : Theme.of(context).textTheme.headline4!.color)
                            .visible(productDetailNew!.store!.shopName.validate().isNotEmpty),
                      if (productDetailNew!.store != null)
                        Row(
                          children: [
                            Text(appLocalization!.translate('lbl_sold_by')!, style: primaryTextStyle(size: 14, color: Theme.of(context).textTheme.subtitle1!.color))
                                .visible(productDetailNew!.store!.shopName.validate().isNotEmpty),
                            8.width,
                            Text(productDetailNew!.store!.shopName != null ? productDetailNew!.store!.shopName! : '', style: boldTextStyle(color: primaryColor)).onTap(() {
                              VendorProfileScreen(mVendorId: productDetailNew!.store!.id).launch(context);
                            })
                          ],
                        ).paddingOnly(top: 8, left: 16, right: 8, bottom: 8).visible(productDetailNew!.store!.shopName.validate().isNotEmpty),
                      Divider(thickness: 6, color: appStore.isDarkMode! ? white.withOpacity(0.2) : Theme.of(context).textTheme.headline4!.color)
                          .visible(productDetailNew!.onSale! && productDetailNew!.dateOnSaleFrom!.isNotEmpty),
                      if (productDetailNew!.onSale!) productDetailNew!.dateOnSaleFrom!.isNotEmpty ? mSpecialPrice(appLocalization!.translate('lbl_special_msg')) : SizedBox(),
                      if (productDetailNew!.type == "variable" || productDetailNew!.type == "variation")
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Divider(thickness: 6, color: appStore.isDarkMode! ? white.withOpacity(0.2) : Theme.of(context).textTheme.headline4!.color),
                            Text(appLocalization!.translate('lbl_Available')!, style: boldTextStyle()).paddingOnly(left: 16, right: 16),
                            Container(
                              margin: EdgeInsets.only(left: 14.0, right: 16.0, top: 8),
                              decoration: boxDecorationWithRoundedCorners(borderRadius: radius(8), backgroundColor: Theme.of(context).colorScheme.background),
                              padding: EdgeInsets.only(left: 8, right: 8),
                              child: Theme(
                                data: Theme.of(context).copyWith(canvasColor: Theme.of(context).cardTheme.color),
                                child: DropdownButton(
                                  value: mSelectedVariation,
                                  isExpanded: true,
                                  underline: SizedBox(),
                                  onChanged: (dynamic value) {
                                    setState(() {
                                      mSelectedVariation = value;
                                      int index = mProductOptions.indexOf(value);
                                      mProducts.forEach((product) {
                                        if (mProductVariationsIds[index] == product.id) {
                                          this.productDetailNew = product;
                                        }
                                      });
                                      setPriceDetail();
                                      mImage();
                                    });
                                  },
                                  items: mProductOptions.map((value) {
                                    log(mProductOptions);
                                    return DropdownMenuItem(value: value, child: Text(value!, style: primaryTextStyle(color: Theme.of(context).textTheme.subtitle1!.color)));
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ).visible(mProductOptions.length != 0)
                      else if (productDetailNew!.type == "grouped")
                        mGroupAttribute(product)
                      else if (productDetailNew!.type == "simple")
                        Container()
                      else if (productDetailNew!.type == "external")
                        mExternalAttribute()
                      else
                        mOtherAttribute(),
                      mUpcomingSale().visible(!productDetailNew!.onSale!),
                      Divider(thickness: 6, color: appStore.isDarkMode! ? white.withOpacity(0.2) : Theme.of(context).textTheme.headline4!.color).visible(productDetailNew!.description!.isNotEmpty),
                      Text(appLocalization!.translate('lbl_product_details')!, style: boldTextStyle()).paddingOnly(top: 4, left: 16, right: 16).visible(productDetailNew!.description!.isNotEmpty),
                      HtmlWidget(postContent: productDetailNew!.description).paddingOnly(left: 10).visible(productDetailNew!.description!.isNotEmpty),
                      if (productDetailNew!.attributes != null) mSetAttribute().paddingBottom(8),
                      Divider(thickness: 6, color: appStore.isDarkMode! ? white.withOpacity(0.2) : Theme.of(context).textTheme.headline4!.color)
                          .visible(productDetailNew!.shortDescription.toString().isNotEmpty),
                      Text(appLocalization.translate('lbl_short_description')!, style: boldTextStyle())
                          .paddingOnly(top: 4, left: 16, right: 16)
                          .visible(productDetailNew!.shortDescription.toString().isNotEmpty),
                      HtmlWidget(postContent: productDetailNew!.shortDescription).paddingOnly(left: 10, right: 16).visible(productDetailNew!.shortDescription.toString().isNotEmpty),
                      Divider(thickness: 6, color: appStore.isDarkMode! ? white.withOpacity(0.2) : Theme.of(context).textTheme.headline4!.color)
                          .visible(productDetailNew!.categories != null && productDetailNew!.categories!.isNotEmpty),
                      if (productDetailNew!.categories != null && productDetailNew!.categories!.isNotEmpty)
                        Text(appLocalization.translate('lbl_category')!, style: boldTextStyle()).paddingOnly(top: 4, left: 16, right: 16).visible(productDetailNew!.categories != null),
                      if (productDetailNew!.categories != null && productDetailNew!.categories!.isNotEmpty)
                        Wrap(
                          children: productDetailNew!.categories!.map((e) {
                            return Container(
                              margin: EdgeInsets.only(right: 8, bottom: 10),
                              padding: EdgeInsets.all(8),
                              decoration:
                                  boxDecorationWithRoundedCorners(borderRadius: radius(8), backgroundColor: appStore.isDarkMode! ? white.withOpacity(0.2) : Theme.of(context).colorScheme.background),
                              child: Text(e.name!, style: secondaryTextStyle()),
                            ).onTap(() {
                              ViewAllScreen(e.name, isCategory: true, categoryId: e.id).launch(context);
                            });
                          }).toList(),
                        ).paddingOnly(top: 16, left: 16, right: 16),
                      Divider(thickness: 6, color: appStore.isDarkMode! ? white.withOpacity(0.2) : Theme.of(context).textTheme.headline4!.color).visible(productDetailNew!.upSellId!.isNotEmpty),
                      if (productDetailNew!.upSellIds != null) upSaleProductList(productDetailNew!.upSellId!).visible(productDetailNew!.upSellId!.isNotEmpty),
                      Divider(thickness: 6, color: appStore.isDarkMode! ? white.withOpacity(0.2) : Theme.of(context).textTheme.headline4!.color).visible(mReviewModel.isNotEmpty),
                      8.height,
                      _review(),
                      40.height,
                    ],
                  ),
                )
              ],
            ),
          )
        : SizedBox();

    return Scaffold(
      appBar: AppBar(
          elevation: 0,
          backgroundColor: primaryColor,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: white),
            onPressed: () {
              finish(context);
              appStore.setLoading(false);
            },
          ),
          actions: [mCart(context, getBoolAsync(IS_LOGGED_IN), color: white)],
          title: Text(productDetailNew != null ? productDetailNew!.name! : ' ', style: boldTextStyle(color: Colors.white, size: 18)),
          automaticallyImplyLeading: false),
      body: Observer(builder: (context) {
        return BodyCornerWidget(
          child: Stack(
            alignment: Alignment.bottomLeft,
            children: <Widget>[
              productDetailNew != null ? body : SizedBox(),
              Center(child: mProgress()).visible(appStore.isLoading),
            ],
          ),
        );
      }),
      bottomNavigationBar: Container(
              width: context.width(),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: <BoxShadow>[
                  BoxShadow(color: Theme.of(context).hoverColor.withOpacity(0.8), blurRadius: 15.0, offset: Offset(0.0, 0.75)),
                ],
              ),
              child: Row(
                children: [mFavourite.expand(flex: 1), 16.width, mCartData.expand(flex: 1)],
              ).paddingOnly(top: 8, bottom: 8, right: 16, left: 16).visible(productDetailNew != null && productDetailNew!.type != 'grouped'))
          .visible(productDetailNew != null),
    );
  }
}
