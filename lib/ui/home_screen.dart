import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:expand_widget/expand_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mozlit_driver/api/api.dart';
import 'package:mozlit_driver/controller/home_controller.dart';
import 'package:mozlit_driver/controller/user_controller.dart';
import 'package:mozlit_driver/enum/error_type.dart';
import 'package:mozlit_driver/enum/provider_ui_selection_type.dart';
import 'package:mozlit_driver/enum/user_module_type.dart';
import 'package:mozlit_driver/model/home_active_trip_model.dart';
import 'package:mozlit_driver/ui/drawer_srceen/finding_driver_dialog_for_breck_down.dart';
import 'package:mozlit_driver/ui/profile_page.dart';
import 'package:mozlit_driver/ui/widget/custom_button.dart';
import 'package:location/location.dart' as location;
import 'package:mozlit_driver/ui/widget/custom_drawer.dart';
import 'package:mozlit_driver/ui/widget/custom_fade_in_image.dart';
import 'package:mozlit_driver/ui/widget/home_widget/availble_request_widget.dart';
import 'package:mozlit_driver/ui/widget/home_widget/invoice_widget.dart';
import 'package:mozlit_driver/ui/widget/home_widget/rating_dialog.dart';
import 'package:mozlit_driver/ui/widget/home_widget/trip_approved_widget.dart';
import 'package:mozlit_driver/ui/widget/no_internet_widget.dart';
import 'package:mozlit_driver/ui/widget/verifiedScreen.dart';
import 'package:mozlit_driver/util/app_constant.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:swipeable_button_view/swipeable_button_view.dart';
import 'package:url_launcher/url_launcher.dart';

import 'drawer_srceen/earning_screen.dart';
import 'drawer_srceen/notification_manager.dart';
import 'drawer_srceen/profile_screen.dart';
import 'drawer_srceen/wallet_screen.dart';
import 'drawer_srceen/your_trips_Screen.dart';
import 'package:get_storage/get_storage.dart';

import 'widget/dialog/instant_ride_confirm_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int selected = 0;
  GlobalKey _repaintBoundaryKey = new GlobalKey();
  Timer? _getTripTimer;

  final CameraPosition _kGooglePlex = const CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962),
    zoom: 14.4746,
  );
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final HomeController _homeController = Get.find();
  final UserController _userController = Get.find();
  RequestElement requestElement = RequestElement();
  location.Location _location = location.Location.instance;
  String? _mapStyle;

  @override
  void initState() {
    rootBundle.loadString('assets/map_style.txt').then((string) {
      _mapStyle = string;
    });
    super.initState();
    WidgetsBinding.instance.addObserver(this);


      _location.changeSettings(distanceFilter: 10);
      _location.onLocationChanged.listen((event) {


        if(_homeController.userCurrentLocation != null){
          print("checkin location");
          if (_homeController.userCurrentLocation?.longitude == 0 &&
              _homeController.userCurrentLocation?.latitude == 0) {
            _homeController.showMarker(
                latLng: LatLng(event.latitude ?? 0, event.longitude ?? 0),
                oldLatLng: LatLng(event.latitude ?? 0, event.longitude ?? 0));
          } else {
            _homeController.showMarker(
                latLng: LatLng(event.latitude ?? 0, event.longitude ?? 0),
                oldLatLng: _homeController.userCurrentLocation ?? LatLng(0, 0));
          }
          _homeController.userCurrentLocation = LatLng(event.latitude ?? 0, event.longitude ?? 0);
        }


      });


    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      _getTripTimer = Timer.periodic(Duration(seconds: 3), (timer) async {

        if (_homeController.homeActiveTripModel.value.is_instant_ride_check !=
            null) {
          if (_homeController
                  .homeActiveTripModel.value.is_instant_ride_check! ==
              0) {
            await _homeController.getTrip();
          } else {
            print("ghare ja");
          }
        }

        if (_homeController.homeActiveTripModel.value.provider_id != null) {
          if (_homeController.homeActiveTripModel.value.breakdown_count_check !=
              0) {
            print("checkREsss");
            print("checkRE");
            _homeController.breakDownSendNewRide();
          }
        }
      });
      Future.delayed(
        Duration(seconds: 7),
        () async {
          print("deleyed");
          await _homeController.getTrip();
        },
      );
    });

    // BackgroundLocation.startLocationService(forceAndroidLocationManager: true);

        // _userController.updateUserModuleType(
        //             userModuleType: UserModuleType.TAXI);
  }

  TextEditingController textController1 = TextEditingController();
  TextEditingController textController2 = TextEditingController();

  bool isHome = false;
  bool isSubmit = false;

  MultiDestination finalDestination = MultiDestination();
  final box = GetStorage();

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    return Scaffold(
      key: _scaffoldKey,
      // drawer: CustomDrawer(),
      resizeToAvoidBottomInset: false,
      body: GetX<UserController>(builder: (userCont) {
        if (userCont.error.value.errorType == ErrorType.internet) {
          return NoInternetWidget();
        }

        bool isUserOffline =
            userCont.userData.value.service?.status == "offline";

        return GetX<HomeController>(builder: (cont) {
          if (cont.error.value.errorType == ErrorType.internet) {
            return NoInternetWidget();
          }
          // bool isUserOffline =
          //       cont.homeActiveTripModel.value.accountStatus == "banned";
          bool isOnBoarding =
              cont.homeActiveTripModel.value.accountStatus == "onboarding";
          bool isCard =
              cont.homeActiveTripModel.value.accountStatus == "card";
          bool isApproved =
              cont.homeActiveTripModel.value.accountStatus == "approved";
          bool isBanned =
              cont.homeActiveTripModel.value.accountStatus == "banned";
          bool isBalance =
              cont.homeActiveTripModel.value.accountStatus == "balance";
          bool isSuspend =
              cont.homeActiveTripModel.value.accountStatus == "suspend";
          return Stack(
            children: [
              Align(
                alignment: Alignment.center,
                child: RepaintBoundary(
                  key: _repaintBoundaryKey,
                  child: Container(
                    width: 25.w,
                    height: 25.w,
                    padding: EdgeInsets.all(2.w),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                    ),
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Color(0xffFF5A5A)),
                          boxShadow: [
                            BoxShadow(
                                color: Color(0xffFF5A5A), blurRadius: 12.w)
                          ]),
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          // border: Border.all(color: Color(0xffFF5A5A)),
                        ),
                        child: CustomFadeInImage(
                          url: userCont.userData.value.avatar != null
                              ? "${ApiUrl.baseImageUrl}${userCont.userData.value.avatar}"
                              : "https://www.kindpng.com/picc/m/52-526237_avatar-profile-hd-png-download.png",
                          //"${ApiUrl.baseImageUrl}${userCont.userData.value.avatar ?? "https://www.pngall.com/wp-content/uploads/5/Profile-Avatar-PNG.png"}",
                          fit: BoxFit.cover,
                          placeHolder: AppImage.icUserPlaceholder,
                          imageLoaded: () async {
                            print("imageLoaded ==> imageLoaded");
                            if (!cont.isCaptureImage.value) {
                              await Future.delayed(
                                  Duration(milliseconds: 1000));
                              _capturePng();
                              cont.isCaptureImage.value = true;
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              GoogleMap(
                mapType: MapType.normal,
                initialCameraPosition: cont.googleMapInitCameraPosition.value,
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                mapToolbarEnabled: false,
                zoomControlsEnabled: false,
                compassEnabled: true,
                rotateGesturesEnabled: false,
                polylines: Set<Polyline>.of(cont.googleMapPolyLine),
                markers: Set<Marker>.of(cont.googleMarkers.values),
                onMapCreated: (GoogleMapController controller) {
                  controller.setMapStyle(_mapStyle);
                  cont.googleMapController = controller;
                  determinePosition();
                },
              ),
              if (isSuspend)
                InkWell(
                  onTap: () {},
                  child: Container(
                    decoration:
                    BoxDecoration(color: Colors.grey.withOpacity(0.4)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Align(
                          alignment: Alignment.center,
                          child: Text(
                            "${cont.homeActiveTripModel.value.statusInfo}",
                            // "Account has been suspended",
                            style: TextStyle(
                                color: Colors.redAccent, fontSize: 20.sp),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (isUserOffline ||
                  cont.homeActiveTripModel.value.accountStatus == "banned" ||
                  isBalance ||
                  isOnBoarding ||
                  isCard)
                InkWell(
                  child: Container(
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isOnBoarding || isBanned || isBalance || isCard)
                          Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 20.w, vertical: 10.h),
                            child: Text(
                              isBalance
                                  ? "Low Balance! Please settle the amount to admin"
                                  : isBanned
                                      ? "Documents are in review will update you once approved by admin."
                                      : isOnBoarding
                                          ? "Your Account is not verified yet!, Please wait…"
                                          : "Your Account is not verified yet!, Please wait…",
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        Image.asset(
                          AppImage.offline,
                          width: 150.w,
                        ),
                      ],
                    ),
                  ),
                ),

              Stack(
                children: [
                  Positioned(
                    bottom: 0.h,
                    left: 0.w,
                    right: 0.w,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (cont.providerUiSelectionType.value ==
                            ProviderUiSelectionType.none ||
                            userCont.selectedUserModuleType.value !=
                                cont.responseUserModuleType.value) ...[
                          if (!isUserOffline)
                            GestureDetector(
                              onTap: () {
                                determinePosition();
                              },
                              child: Padding(
                                padding: EdgeInsets.only(right: 20),
                                child: Container(
                                  height: 40.w,
                                  width: 40.w,
                                  decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius:
                                          BorderRadius.circular(10.r),
                                      boxShadow: [
                                        AppBoxShadow.defaultShadow(),
                                      ]),
                                  child: Center(
                                    child: Image.asset(
                                      AppImage.icGPS,
                                      color: AppColors.primaryColor,
                                      width: 25.w,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          SizedBox(
                            height: 10.h,
                          ),
                          Padding(
                            padding: EdgeInsets.only(
                                bottom: 40, left: 20, right: 20),
                            child: SwipeableButtonView(
                              buttonText: isUserOffline
                                  ? 'swipe_to_online'.tr
                                  : 'swipe_to_offline'.tr,
                              buttontextstyle: TextStyle(
                                  fontSize: 13.sp,
                                  color: AppColors.primaryColor),
                              buttonColor: isUserOffline ? Colors.red : Colors.green,
                              buttonWidget: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:AppColors.primaryColor,
                                  // color:isUserOffline ?Colors.red : Colors.green,
                                ),
                                padding: EdgeInsets.all(10.w),
                                child: Image.asset(
                                  isUserOffline
                                      ? AppImage.icPauseRiding
                                      : AppImage.icRiding,
                                  color:isUserOffline ?Colors.white : Colors.white,
                                ),
                              ),
                              activeColor: isUserOffline ?Colors.white : Colors.white,
                              isFinished: cont.isSwipeCompleted.value,
                              onWaitingProcess: () {
                                cont.providerAvailableStatusChange();
                                // Future.delayed(Duration(milliseconds: 200), () {
                                //   setState(() {
                                //     cont.isSwipeCompleted.value = true;
                                //   });
                                // });
                              },
                              onFinish: () async {
                                cont.isSwipeCompleted.value = false;
                              },
                            ),
                          ),
                        ],

                       if (

                       cont.providerUiSelectionType.value ==
                           ProviderUiSelectionType.searchingRequest &&
                           userCont.selectedUserModuleType.value ==
                               cont.responseUserModuleType.value) ...[
                         AvailableRequestWidget()

                     ],
                        if (cont.providerUiSelectionType.value ==
                                ProviderUiSelectionType.startedRequest ||
                            cont.providerUiSelectionType.value ==
                                ProviderUiSelectionType.approvedRequest ||
                            cont.providerUiSelectionType.value ==
                                ProviderUiSelectionType.arrivedRequest ||
                            cont.providerUiSelectionType.value ==
                                ProviderUiSelectionType.pickedUpRequest) ...[
                          TripApprovedWidget(),
                        ],
                        if (cont.providerUiSelectionType.value ==
                            ProviderUiSelectionType.droppedRequest)
                          InvoiceWidget(),
                      ],
                    ),
                  ),
                  if (_homeController.userCurrentLocation != null) ...[
                    if (cont.breakdownNewRideModel.value.userReqDetails !=
                        null)
                      if (cont.homeActiveTripModel.value
                                  .breakdown_count_check !=
                              0 &&
                          (cont.breakdownNewRideModel.value.userReqDetails!
                                      .first.breakdownStatus ==
                                  "searching" ||
                              cont.breakdownNewRideModel.value.userReqDetails!
                                      .first.breakdownStatus ==
                                  "notassign")) ...[
                        FindingDriverForBreakDownDialog()
                      ],
                  ]
                ],
              ),

              // if (cont.providerUiSelectionType.value ==
              //         ProviderUiSelectionType.startedRequest ||
              //     cont.providerUiSelectionType.value ==
              //         ProviderUiSelectionType.approvedRequest ||
              //     cont.providerUiSelectionType.value ==
              //         ProviderUiSelectionType.arrivedRequest ||
              //     cont.providerUiSelectionType.value ==
              //         ProviderUiSelectionType.pickedUpRequest) ...[
              //   Positioned(
              //       top: 200,
              //       child: Container(
              //         child: Row(
              //           children: [
              //             Padding(
              //               padding: EdgeInsets.only(right: 20),
              //               child: Container(
              //                 height: 40.w,
              //                 width: 40.w,
              //                 decoration: BoxDecoration(
              //                     color: Colors.white,
              //                     borderRadius: BorderRadius.circular(10.r),
              //                     boxShadow: [
              //                       AppBoxShadow.defaultShadow(),
              //                     ]),
              //                 child: Center(
              //                   child: Text(
              //                       'To:   ${requestElement.request?.dAddress ?? ""}'),
              //                 ),
              //               ),
              //             ),
              //             GestureDetector(
              //               onTap: () {
              //                 determinePosition();
              //               },
              //               child: Padding(
              //                 padding: EdgeInsets.only(right: 20),
              //                 child: Container(
              //                   height: 40.w,
              //                   width: 40.w,
              //                   decoration: BoxDecoration(
              //                       color: Colors.white,
              //                       borderRadius: BorderRadius.circular(10.r),
              //                       boxShadow: [
              //                         AppBoxShadow.defaultShadow(),
              //                       ]),
              //                   child: Center(
              //                     child: Image.asset(
              //                       AppImage.icGPS,
              //                       width: 25.w,
              //                     ),
              //                   ),
              //                 ),
              //               ),
              //             ),
              //           ],
              //         ),
              //       )),
              // ],

              if (cont.homeActiveTripModel.value.breakdown_count_check == 0 &&
                  cont.providerUiSelectionType.value ==
                      ProviderUiSelectionType.completedRequest) ...[
                Align(
                    alignment: Alignment.bottomCenter, child: RatingDialog())
              ],
              // if (cont.homeActiveTripModel.value.requests.isNotEmpty) ...[
              //           if(cont.homeActiveTripModel.value.breakdown_count_check == 1 &&
              //               cont.homeActiveTripModel.value.requests.first.request!.breakdown_status == "assign") ... [ Align(
              //               alignment: Alignment.bottomCenter, child: RatingDialog())]

              // ]
              // ,

              Positioned(
                  top: 40,
                  child: Padding(
                    padding: const EdgeInsets.only(top:8.0),
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width,
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,

                          children: [
                            // if (cont.userUiSelectionType.value !=
                            //         UserUiSelectionType.serviceType &&
                            //     cont.userUiSelectionType.value !=
                            //         UserUiSelectionType.vehicleDetails &&
                            //     cont.userUiSelectionType.value !=
                            //         UserUiSelectionType.scheduleRide &&
                            //     cont.userUiSelectionType.value !=
                            //         UserUiSelectionType.findingDriver)
                            Column(
                              children: [
                                Container(
                                  height:
                                  MediaQuery.of(context).size.height *
                                      0.085,
                                  width:
                                  MediaQuery.of(context).size.width *
                                      0.95,
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryColor,
                                    borderRadius: BorderRadius.all(
                                        Radius.circular(55)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                    CrossAxisAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment.start,
                                        crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                        children: [
                                          InkWell(
                                            onTap: () {
                                              Get.to(
                                                      () => ProfileScreen());

                                            },
                                            child: Stack(
                                              children: [
                                                Padding(
                                                  padding:
                                                  EdgeInsets.all(2.0),
                                                  child: Container(
                                                    height: 45.w,
                                                    width: 45.w,
                                                    clipBehavior:
                                                    Clip.antiAlias,
                                                    decoration:
                                                    BoxDecoration(
                                                      // color: Colors.red,
                                                        border:
                                                        Border.all(
                                                          color: AppColors
                                                              .primaryColor,
                                                          width: 1,
                                                        ),
                                                        borderRadius:
                                                        BorderRadius
                                                            .circular(
                                                            25.h)),
                                                    padding:
                                                    EdgeInsets.all(1),
                                                    child: userCont
                                                        .userData
                                                        .value
                                                        .avatar ==
                                                        null
                                                        ? CircleAvatar(
                                                      radius: 25,
                                                      backgroundColor:
                                                      AppColors
                                                          .white,
                                                      backgroundImage:
                                                      AssetImage(
                                                          AppImage
                                                              .profilePic),
                                                    )
                                                        : CircleAvatar(
                                                      radius: 25,
                                                      backgroundImage:
                                                      NetworkImage(
                                                        '${ApiUrl.baseImageUrl}${userCont.userData.value.avatar}',
                                                      ),
                                                      backgroundColor:
                                                      AppColors
                                                          .white,
                                                      // child: CustomFadeInImage(
                                                      //     url:
                                                      //         '${ApiUrl.baseImageUrl}${_userController.userData.value.picture}',
                                                      //     fit: BoxFit
                                                      //         .contain,
                                                      //     placeHolder:
                                                      //         AppImage
                                                      //             .icUserPlaceholder,
                                                      //   ),
                                                    ),
                                                  ),
                                                ),
                                                cont.homeActiveTripModel.value.providerVerifyCheck == null? SizedBox() :
                                                cont.homeActiveTripModel.value.providerVerifyCheck == 'verified'?
                                                Positioned(bottom:0, right:0,child: Container(height:20, width:20,decoration: BoxDecoration(
                                                    color:Colors.white,shape: BoxShape.circle
                                                ),
                                                    child: Image.asset(AppImage.verifiedIcon,height: 20,width: 20,)),) : SizedBox()
                                              ],
                                            ),
                                          ),
                                          SizedBox(
                                            width: 8,
                                          ),
                                          Column(
                                            mainAxisAlignment:
                                            MainAxisAlignment.center,
                                            crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                            children: [
                                              RichText(
                                                text: TextSpan(
                                                  text: 'hi'.tr,
                                                  style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                      FontWeight.w500,
                                                      color: AppColors
                                                          .white),
                                                  children: <TextSpan>[
                                                    TextSpan(
                                                        text:
                                                        ' ${userCont.userData.value.firstName ?? ""} ${userCont.userData.value.lastName ?? ""} ',
                                                        style: TextStyle(
                                                            fontSize: 16,
                                                            color: AppColors
                                                                .white,
                                                            fontWeight:
                                                            FontWeight
                                                                .w500)),
                                                  ],
                                                ),
                                              ),

                                              Text('have_a_nice_day'.tr,
                                                  style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                      FontWeight
                                                          .w500,
                                                      color: AppColors
                                                          .white)),
                                            ],
                                          ),
                                        ],
                                      ),
                                      InkWell(
                                        onTap: () {
                                          //VerifiedDialogue()
                                          Get.to(() => NotificationManagerScreen());
                                          //GetStorage().erase();
                                        },
                                        child: Padding(
                                          padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12.0),
                                          child: Image.asset(
                                              AppImage.bell,color: AppColors.white,
                                              height: 30,
                                              width: 30),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Stack(children: [
                                //
                                //
                                // ],),
                                Stack(alignment: Alignment.center,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2.0),
                                      child: Container(width: 42,height: 38,decoration: BoxDecoration(color:
                                      AppColors.primaryColor,borderRadius: BorderRadius.circular(20)),child: Align(alignment:
                                      Alignment.center,child: Icon(Icons.sort,color: Colors.white,),),),
                                    ),
                                    ExpandChild(
                                      arrowPadding: EdgeInsets.only(bottom: 20),
                                        arrowColor: AppColors.primaryColor,
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 5),

                                          height: MediaQuery.of(context)
                                              .size
                                              .height *
                                              0.12,
                                          alignment: Alignment.center,
                                          width: MediaQuery.of(context)
                                              .size
                                              .width *
                                              0.95,
                                          decoration: BoxDecoration(
                                            color: AppColors.white,
                                            borderRadius: BorderRadius.all(
                                                Radius.circular(25)),
                                          ),
                                          // height: 100,
                                          child: Row(
                                            mainAxisAlignment:
                                            MainAxisAlignment.spaceAround,
                                            children: [
                                              InkWell(
                                                onTap: () {
                                                  Get.to(() => EarningScreen(
                                                  ));
                                                },
                                                child: Container(
                                                    padding: EdgeInsets.only(
                                                        top: 7,
                                                        bottom: 7,
                                                        left: 0,
                                                        right: 0),
                                                    height: 80,
                                                    width: 80,
                                                    decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius:
                                                        BorderRadius
                                                            .circular(
                                                            10)),
                                                    child: Column(
                                                      mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceAround,
                                                      children: [
                                                        Image.asset(
                                                          AppImage.earning,
                                                          height: 35,
                                                          width: 35,
                                                        ),

                                                        Text(
                                                          'earning'.tr,
                                                          style: TextStyle(
                                                              fontSize: 12),
                                                        )
                                                      ],
                                                    )),
                                              ),
                                              InkWell(
                                                onTap: () {
                                                  Get.to(() => YourTripsScreen());
                                                },
                                                child: Container(
                                                    padding:
                                                    EdgeInsets.all(7),
                                                    height: 80,
                                                    width: 80,
                                                    decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius:
                                                        BorderRadius
                                                            .circular(
                                                            10)),
                                                    child: Column(
                                                      mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceAround,
                                                      children: [
                                                        Image.asset(
                                                          AppImage.pastRide,
                                                          height: 30,
                                                          width: 30,
                                                        ),
                                                        SizedBox(height: 5),
                                                        Text(
                                                          'past_rides'.tr,
                                                          style: TextStyle(
                                                              fontSize: 12),
                                                        )
                                                      ],
                                                    )),
                                              ),
                                              InkWell(
                                                onTap: () {
                                                  Get.to(() => ProfilePage());
                                                },
                                                child: Container(
                                                    padding:
                                                    EdgeInsets.all(7),
                                                    height: 80,
                                                    width: 80,
                                                    decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius:
                                                        BorderRadius
                                                            .circular(
                                                            10)),
                                                    child: Column(
                                                      mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceAround,
                                                      children: [
                                                        Image.asset(
                                                          AppImage.account,
                                                          height: 30,
                                                          width: 30,
                                                        ),
                                                        SizedBox(height: 5),
                                                        Text(
                                                          'account'.tr,
                                                          style: TextStyle(
                                                              fontSize: 12),
                                                        )
                                                      ],
                                                    )),
                                              ),
                                            ],
                                          ),
                                        )),
                                  ],
                                ),
                                SizedBox(
                                  height: 10.h,
                                ),
                                // if (cont.providerUiSelectionType.value ==
                                //     ProviderUiSelectionType.none ||
                                //     userCont.selectedUserModuleType.value !=
                                //         cont.responseUserModuleType.value)
                                //   Container(
                                //     clipBehavior: Clip.antiAlias,
                                //     decoration: BoxDecoration(
                                //         color: AppColors.unselectedColor,
                                //         borderRadius: BorderRadius.circular(30.r)),
                                //     child: Row(
                                //       children: [
                                //         InkWell(
                                //           onTap: () async {
                                //             userCont.updateUserModuleType(
                                //                 userModuleType: UserModuleType.TAXI);
                                //             // userCont.selectedUserModuleType.value = UserModuleType.TAXI;
                                //           },
                                //           child: Container(
                                //             child: Center(
                                //               child: Text(
                                //                 "taxi".tr,
                                //                 style: TextStyle(
                                //                   color: userCont.selectedUserModuleType
                                //                       .value ==
                                //                       UserModuleType.TAXI
                                //                       ? AppColors.unselectedColor
                                //                       : AppColors.selectedColor,
                                //                   fontSize: 16.sp,
                                //                 ),
                                //               ),
                                //             ),
                                //             width: 105.w,
                                //             height: 47.w,
                                //             decoration: BoxDecoration(
                                //               color: userCont.selectedUserModuleType
                                //                   .value ==
                                //                   UserModuleType.TAXI
                                //                   ? AppColors.selectedColor
                                //                   : AppColors.unselectedColor,
                                //             ),
                                //           ),
                                //         ),
                                //         InkWell(
                                //           onTap: () async {
                                //             userCont.updateUserModuleType(
                                //                 userModuleType:
                                //                 UserModuleType.DELIVERY);
                                //             // userCont.selectedUserModuleType.value = UserModuleType.DELIVERY;
                                //           },
                                //           child: Container(
                                //             child: Center(
                                //               child: Text(
                                //                 "delivery".tr,
                                //                 style: TextStyle(
                                //                   color: userCont.selectedUserModuleType
                                //                       .value ==
                                //                       UserModuleType.DELIVERY
                                //                       ? AppColors.unselectedColor
                                //                       : AppColors.selectedColor,
                                //                   fontSize: 16.sp,
                                //                 ),
                                //               ),
                                //             ),
                                //             decoration: BoxDecoration(
                                //               color: userCont.selectedUserModuleType
                                //                   .value ==
                                //                   UserModuleType.DELIVERY
                                //                   ? AppColors.selectedColor
                                //                   : AppColors.unselectedColor,
                                //             ),
                                //             width: 105.w,
                                //             height: 47.w,
                                //           ),
                                //         ),
                                //         // InkWell(
                                //         //   onTap: () async {
                                //         //     userCont.selectedUserModuleType.value = UserModuleType.BOTH;
                                //         //
                                //         //
                                //         //
                                //         //      // cont.selectedUserModuleType.value = cont.responseUserModuleType.value;
                                //         //      },
                                //         //   child: Container(
                                //         //     width: 105.w,
                                //         //     height: 47.w,
                                //         //
                                //         //     child: Center(
                                //         //       child: Text("Both",
                                //         //         style: TextStyle(
                                //         //           color: userCont.selectedUserModuleType.value == UserModuleType.BOTH
                                //         //               ? AppColors.unselectedColor
                                //         //               : AppColors.selectedColor,
                                //         //           fontSize: 16.sp,
                                //         //         ),
                                //         //       ),
                                //         //     ),
                                //         //     decoration: BoxDecoration(
                                //         //         color: userCont.selectedUserModuleType.value == UserModuleType.BOTH
                                //         //             ? AppColors.selectedColor
                                //         //             : AppColors.unselectedColor,
                                //         //         borderRadius: BorderRadius.only(
                                //         //           topRight: Radius.circular(30.r),
                                //         //           bottomRight: Radius.circular(30.r),
                                //         //         )),
                                //         //   ),
                                //         // ),
                                //       ],
                                //     ),
                                //   ),
                                if (cont.homeAddress.isNotEmpty) ...[
                                  Expanded(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: ConstrainedBox(
                                            constraints:
                                            BoxConstraints(minHeight: 40.w),
                                            child: Container(
                                              margin: EdgeInsets.symmetric(
                                                  horizontal: 10.w),
                                              padding: EdgeInsets.symmetric(
                                                  vertical: 3.h, horizontal: 10.w),
                                              alignment: Alignment.centerLeft,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                BorderRadius.circular(12.r),
                                                boxShadow: [
                                                  AppBoxShadow.defaultShadow(),
                                                ],
                                              ),
                                              child: Text(
                                                "${cont.homeAddress.value}",
                                                // maxLines: 2,
                                                style: TextStyle(fontSize: 12.sp),
                                                // overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () async {
                                            // _scaffoldKey.currentState!.openDrawer();
                                            // var uri = Uri.parse("google.navigation:q=${cont.homeAddress.value.replaceAll(",,", ",")}");
                                            var uri = Uri.parse(
                                                "google.navigation://q=${cont.googleMapLatLng.latitude},${cont.googleMapLatLng.longitude}&mode=d");
                                            if (Platform.isIOS) {
                                              uri = Uri.parse(
                                                  "https://maps.apple.com?q=${cont.googleMapLatLng.latitude},${cont.googleMapLatLng.longitude}&mode=d");
                                            }
                                            if (await canLaunchUrl(uri)) {
                                              await launchUrl(uri);
                                            } else {
                                              cont.showError(
                                                  msg:
                                                  "${"could_not_launch".tr} $uri");
                                            }
                                          },
                                          child: Container(
                                            height: 40.w,
                                            width: 40.w,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                              BorderRadius.circular(12.r),
                                              boxShadow: [
                                                AppBoxShadow.defaultShadow(),
                                              ],
                                            ),
                                            child: Center(
                                              child: Image.asset(
                                                AppImage.icHomeLocation,
                                                width: 22.w,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ]),
                    ),
                  )),

              if (cont.providerUiSelectionType.value ==
                      ProviderUiSelectionType.startedRequest ||
                  cont.providerUiSelectionType.value ==
                      ProviderUiSelectionType.approvedRequest) ...[
                Positioned(
                  top: 55,
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 15),
                    padding: EdgeInsets.symmetric(horizontal: 5),
                    height: 50,
                    width: MediaQuery.of(context).size.width * 0.9,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15)),
                    child: Row(
                      // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(
                          width: 5,
                        ),
                        Text(
                          'To:',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.black,
                              fontWeight: FontWeight.w600),
                        ),
                        SizedBox(
                          width: 3,
                        ),
                        Expanded(
                          child: Text(
                            // '',
                            '${cont.homeActiveTripModel.value.multiDestination[0].dAddress}',
                            overflow: TextOverflow.ellipsis,
                            //'${cont.homeAddress}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[500]),
                          ),
                        ),
                        InkWell(
                          onTap: () async {
                            String googleUrl =
                                'https://www.google.com/maps/search/?api=1&query=${cont.googleMapLatLng.latitude},${cont.googleMapLatLng.longitude}';
                            if (await canLaunch(googleUrl)) {
                              await launch(googleUrl);
                            } else {
                              final scaffold = ScaffoldMessenger.of(context);
                              scaffold.showSnackBar(SnackBar(
                                content:
                                    const Text('Could not open the map.'),
                                action: SnackBarAction(
                                    label: 'UNDO',
                                    onPressed: scaffold.hideCurrentSnackBar),
                              ));
                              // throw '';
                            }
                          },
                          child: Container(
                            height: 40.w,
                            width: 40.w,
                            padding: EdgeInsets.all(10.w),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10.r),
                              boxShadow: [
                                AppBoxShadow.defaultShadow(),
                              ],
                            ),
                            child: Icon(
                              Icons.map_outlined,
                              size: 25,
                              color: AppColors.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              if (cont.providerUiSelectionType.value ==
                      ProviderUiSelectionType.arrivedRequest ||
                  cont.providerUiSelectionType.value ==
                      ProviderUiSelectionType.pickedUpRequest) ...[
                Positioned(
                  top: 55,
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 15),
                    padding: EdgeInsets.symmetric(horizontal: 5),
                    height: 50,
                    width: MediaQuery.of(context).size.width * 0.9,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15)),
                    child: Row(
                      // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(
                          width: 5,
                        ),
                        Text(
                          'To:',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.black,
                              fontWeight: FontWeight.w600),
                        ),
                        SizedBox(
                          width: 3,
                        ),
                        // TextButton(
                        //     onPressed: () {
                        //       print(
                        //           "instantRideConfirm===>${instantRideConfirm}");
                        //       print(
                        //           "cont.homeActiv===>${cont.homeActiveTripModel.value.requests[0].request!.dLatitude}");
                        //       print(
                        //           "cont.homeActiv===>${cont.homeActiveTripModel.value.requests[0].request!.dLongitude}");
                        //     },
                        //     child: Text("data")),
                        Expanded(
                          child: instantRideConfirm
                              ? Text(
                                  cont.homeActiveTripModel.value.requests[0]
                                      .request!.dAddress!,
                                  overflow: TextOverflow.ellipsis,
                                  //cont.tempLocationWhereTo1.text,overflow: TextOverflow.ellipsis,
                                  //'${cont.homeActiveTripModel.value.multiDestination[0].dAddress}',
                                  //overflow: TextOverflow.ellipsis,
                                  //"${cont.tempLocationWhereTo1.text}",overflow: TextOverflow.ellipsis,
                                  //'${cont.homeActiveTripModel.value.multiDestination.isEmpty ? "" : cont.homeActiveTripModel.value.multiDestination[0].dAddress}',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[500]),
                                )
                              : Text(
                                  cont.homeActiveTripModel.value
                                          .multiDestination.isEmpty
                                      ? ""
                                      : '${cont.homeActiveTripModel.value.multiDestination[0].dAddress}',
                                  overflow: TextOverflow.ellipsis,
                                  //cont.tempLocationWhereTo1.text,overflow: TextOverflow.ellipsis,
                                  //'${cont.homeActiveTripModel.value.multiDestination[0].dAddress}',
                                  //overflow: TextOverflow.ellipsis,
                                  //"${cont.tempLocationWhereTo1.text}",overflow: TextOverflow.ellipsis,
                                  //'${cont.homeActiveTripModel.value.multiDestination.isEmpty ? "" : cont.homeActiveTripModel.value.multiDestination[0].dAddress}',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[500]),
                                ),
                        ),
                        InkWell(
                          onTap: () async {
                            print("lllat===>$instantRideConfirm}");
                            print(
                                "lllat===>${cont.homeActiveTripModel.value.requests[0].request!.dLatitude}");
                            print(
                                "lllat===>${cont.homeActiveTripModel.value.requests[0].request!.dLongitude}");
                            String googleUrl = instantRideConfirm
                                ? 'https://www.google.com/maps/search/?api=1&query=${cont.homeActiveTripModel.value.requests[0].request!.dLatitude},${cont.homeActiveTripModel.value.requests[0].request!.dLongitude}'
                                : 'https://www.google.com/maps/search/?api=1&query=${cont.homeActiveTripModel.value.multiDestination[0].latitude},${cont.homeActiveTripModel.value.multiDestination[0].longitude}';
                            if (await canLaunch(googleUrl)) {
                              await launch(googleUrl);
                            } else {
                              final scaffold = ScaffoldMessenger.of(context);
                              scaffold.showSnackBar(SnackBar(
                                content:
                                    const Text('Could not open the map.'),
                                action: SnackBarAction(
                                    label: 'UNDO',
                                    onPressed: scaffold.hideCurrentSnackBar),
                              ));
                              // throw '';
                            }
                          },
                          child: Container(
                            height: 40.w,
                            width: 40.w,
                            padding: EdgeInsets.all(10.w),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10.r),
                              boxShadow: [
                                AppBoxShadow.defaultShadow(),
                              ],
                            ),
                            child: Icon(
                              Icons.map_outlined,
                              size: 25,
                              color: AppColors.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              GetStorage().read('isVerifiedPopUpShowed')==null &&
                  cont.homeActiveTripModel.value.userVerifyCheck == 'verified'?
              VerifiedDialogue() : SizedBox()

              // Positioned(
              //   top: 75.h,
              //   left: 25.w,
              //   right: 25.w,
              //   child: Container(
              //     width: MediaQuery.of(context).size.width,
              //     child: Row(
              //       crossAxisAlignment: CrossAxisAlignment.start,
              //       children: [
              //         GestureDetector(
              //           onTap: () {
              //             _scaffoldKey.currentState!.openDrawer();
              //           },
              //           child: Container(
              //             height: 40.w,
              //             width: 40.w,
              //             decoration: BoxDecoration(
              //               color: Colors.white,
              //               borderRadius: BorderRadius.circular(12.r),
              //               boxShadow: [
              //                 AppBoxShadow.defaultShadow(),
              //               ],
              //             ),
              //             child: Center(
              //               child: Image.asset(
              //                 AppImage.icMenu,
              //                 width: 18.w,
              //               ),
              //             ),
              //           ),
              //         ),
              //         if (cont.homeAddress.isNotEmpty) ...[
              //           Expanded(
              //             child: Row(
              //               crossAxisAlignment: CrossAxisAlignment.start,
              //               children: [
              //                 Expanded(
              //                   child: ConstrainedBox(
              //                     constraints: BoxConstraints(minHeight: 40.w),
              //                     child: Container(
              //                       margin:
              //                           EdgeInsets.symmetric(horizontal: 10.w),
              //                       padding: EdgeInsets.symmetric(
              //                           vertical: 3.h, horizontal: 10.w),
              //                       alignment: Alignment.centerLeft,
              //                       decoration: BoxDecoration(
              //                         color: Colors.white,
              //                         borderRadius: BorderRadius.circular(12.r),
              //                         boxShadow: [
              //                           AppBoxShadow.defaultShadow(),
              //                         ],
              //                       ),
              //                       child: Text(
              //                         "${cont.homeAddress.value}",
              //                         // maxLines: 2,
              //                         style: TextStyle(fontSize: 12.sp),
              //                         // overflow: TextOverflow.ellipsis,
              //                       ),
              //                     ),
              //                   ),
              //                 ),
              //                 GestureDetector(
              //                   onTap: () async {
              //                     // _scaffoldKey.currentState!.openDrawer();
              //                     // var uri = Uri.parse("google.navigation:q=${cont.homeAddress.value.replaceAll(",,", ",")}");
              //                     var uri = Uri.parse(
              //                         "google.navigation://q=${cont.googleMapLatLng.latitude},${cont.googleMapLatLng.longitude}&mode=d");
              //                     if (Platform.isIOS) {
              //                       uri = Uri.parse(
              //                           "https://maps.apple.com?q=${cont.googleMapLatLng.latitude},${cont.googleMapLatLng.longitude}&mode=d");
              //                     }
              //                     if (await canLaunchUrl(uri)) {
              //                       await launchUrl(uri);
              //                     } else {
              //                       cont.showError(
              //                           msg: "${"could_not_launch".tr} $uri");
              //                     }
              //                   },
              //                   child: Container(
              //                     height: 40.w,
              //                     width: 40.w,
              //                     decoration: BoxDecoration(
              //                       color: Colors.white,
              //                       borderRadius: BorderRadius.circular(12.r),
              //                       boxShadow: [
              //                         AppBoxShadow.defaultShadow(),
              //                       ],
              //                     ),
              //                     child: Center(
              //                       child: Image.asset(
              //                         AppImage.icHomeLocation,
              //                         width: 22.w,
              //                       ),
              //                     ),
              //                   ),
              //                 ),
              //               ],
              //             ),
              //           ),
              //         ],
              //       ],
              //     ),
              //   ),
              // ),
              // _bottomCard(width: width)
            ],
          );
        });
      }),
    );
  }

  Future<Position?> determinePosition() async {
    LocationPermission permission;

    // Test if location services are enabled.

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        Get.showSnackbar(GetSnackBar(
          messageText: Text(
            "location_permissions_are_denied".tr,
            style: TextStyle(
              color: Colors.white,
            ),
          ),
          mainButton: InkWell(
            onTap: () {},
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 15),
              child: Text(
                "allow".tr,
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ));
      }
    }

    if (permission == LocationPermission.deniedForever) {
      await openAppSettings();
    }
    Position? position;
    try {
      position = await Geolocator.getCurrentPosition();
    } catch (e) {
      Get.showSnackbar(GetSnackBar(
        messageText: Text(
          e.toString(),
          style: const TextStyle(
            color: Colors.white,
          ),
        ),
        mainButton: InkWell(
          onTap: () {},
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 15),
            child: Text(
              "allow".tr,
              style: TextStyle(
                color: Colors.orange,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ));
      // showError(msg: e.toString());
    }
    if (position != null) {
      LatLng latLng = LatLng(position.latitude, position.longitude);
      _homeController.userCurrentLocation = latLng;
      CameraPosition cameraPosition = CameraPosition(
        target: LatLng(latLng.latitude, latLng.longitude),
        zoom: 14.4746,
      );
      _homeController.googleMapController
          ?.animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
      if (_homeController.userImageMarker != null) {
        _homeController.showMarker(
            latLng: _homeController.userCurrentLocation!,
            oldLatLng: _homeController.userCurrentLocation!);
      } else {
        _capturePng();
      }
    }
    return position;
  }

  @override
  void dispose() {
    super.dispose();
    // BackgroundLocation.stopLocationService();
    WidgetsBinding.instance.removeObserver(this);
    _getTripTimer?.cancel();
  }

  Future<Uint8List?> _capturePng() async {
    try {
      print('inside');
      RenderRepaintBoundary? boundary = _repaintBoundaryKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      ui.Image? image = await boundary?.toImage(pixelRatio: 3);
      ByteData? byteData =
          await image?.toByteData(format: ui.ImageByteFormat.png);
      var pngBytes = byteData?.buffer.asUint8List();
      _homeController.userImageMarker = pngBytes;
      var bs64 = base64Encode(pngBytes!);
      print(pngBytes);
      print(bs64);
      if (_homeController.userCurrentLocation != null) {
        _homeController.showMarker(
            latLng: _homeController.userCurrentLocation!,
            oldLatLng: LatLng(0, 0));
      }
      return pngBytes;
    } catch (e) {
      print(e);
      _homeController.isCaptureImage.value = false;
    }
    return null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        if (_homeController.googleMapController != null) {
          _homeController.googleMapController?.setMapStyle("[]");
        }
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.paused:
        break;
      case AppLifecycleState.detached:
        break;
    }
  }
}
