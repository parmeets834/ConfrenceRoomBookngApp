import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:kkconferences/api/FirbaseApi.dart';
import 'package:kkconferences/global/Global.dart';
import 'package:kkconferences/global/const_funcitons.dart';
import 'package:kkconferences/global/constants.dart';
import 'package:kkconferences/model/booking_model.dart';
import 'package:kkconferences/utils/dialog.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:uuid/uuid.dart';

class BookingHelper {
  BuildContext context;
  BookingModel errorModel;
  Razorpay razorpay;

  getBookings(DateTime date) async {
    QuerySnapshot snapshot = await FireBaseApi().getSelectedDateBookings(
        model: BookingModel(bookingDate: getFirebaseFormatDate(date)));
    return snapshot;
  }

  Future<bool> checkIsBookingExist(
      {TimeOfDay endTime, TimeOfDay startTime, DateTime date}) async {
    print("we called");
    int cuuruntMeetingStartInDuration =
        Duration(hours: startTime.hour, minutes: startTime.minute).inSeconds;
    int cuuruntMeetingEndInDuration =
        Duration(hours: endTime.hour, minutes: endTime.minute).inSeconds;
    QuerySnapshot snapshot = await getBookings(date);
    for (QueryDocumentSnapshot item in snapshot.docs) {
      BookingModel model = BookingModel.fromJson(item.data());
      if (cuuruntMeetingStartInDuration <= model.bookingStartduration &&
          cuuruntMeetingStartInDuration >= model.bookingEndduration) {
        /*
    booking start duration is 47000
    selected start duration is 48000
    booking end duration 51000
    selected end duration 540000
    470000<480000 &&  480000<510000
    */
        errorModel = model;
        print("clash of scenerio 1");
        return false;
      } else if (model.bookingStartduration <= cuuruntMeetingEndInDuration &&
          cuuruntMeetingEndInDuration <= model.bookingEndduration) {
        /*
    booking start duration is 47000
     booking end duration 60000
    selected start duration is 48000
    selected end duration 540000
    470000<540000 &&  540000<60000
    */
        errorModel = model;
        print("clash of scenerio 2");
        return false;
      } else if (cuuruntMeetingStartInDuration < model.bookingStartduration &&
          cuuruntMeetingEndInDuration < model.bookingEndduration) {
        print("clash of scenerio 3");
      } else if (cuuruntMeetingStartInDuration > model.bookingStartduration &&
          cuuruntMeetingEndInDuration < model.bookingEndduration) {
        print("clash of scenerio 4");
      }
    }
    return true;
  }

  TimeOfDay startTime;
  TimeOfDay endTime;
  DateTime date;
  double amount;

  performBooking(BuildContext context,
      { endTime,
      TimeOfDay startTime,
      DateTime date,
      double amount}) async {


    bool booking_flag = await checkIsBookingExist(
        endTime: endTime, startTime: startTime, date: date);
    if (booking_flag == false) {
      DialogUtil(
        context: context,
        message:
            "This Slot is Booked \n From ${getDateWith12HrsFormat(errorModel.bookingStartTime)} To: ${getDateWith12HrsFormat(errorModel.bookingEndTime)}",
        title: "Error Booking Already Exist",
      ).showErrorDialog();
      return;
    }
    this.endTime=endTime;
    this.startTime=startTime;
    this.date=date;
    this.amount;

   await initRazorPay();
   openCheckout(amount, "Booking for ${getFormattedTime(startTime)} to ${getFormattedTime(endTime)} on ${getFirebaseFormatDate(date)}");
  }

  void convertSecondsToTime(int seconds) {
    Duration duration = Duration(seconds: seconds);

    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    // return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    print("${duration.inHours} mins ${twoDigitMinutes} ");
  }

  /*There is payment gateway code */
  void initRazorPay() {
    razorpay = Razorpay();
    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void openCheckout(double amount, String description) async {
    var options = {
      'key': razor_key,
      'amount': amount*100,
      'name': '$company_name',
      'description': '$description',
      'prefill': {'contact': ' $phno', 'email': '$email'},
      'external': {
        'wallets': ['paytm']
      }
    };

    try {
      razorpay.open(options);
    } catch (e) {
      debugPrint(e);
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    Fluttertoast.showToast(
        msg: "SUCCESS: " + response.paymentId, timeInSecForIosWeb: 4);

    startTime = TimeOfDay(hour: startTime.hour, minute: startTime.minute + 1);
    var uuid = Uuid();
    FireBaseApi().addBookingEntery(
        model: BookingModel(
          bookingDate: getFirebaseFormatDate(date),
          bookingStartTime: getDatewithTime(date, startTime),
          bookingEndTime: getDatewithTime(date, endTime),
          bookingStartduration:
          Duration(hours: startTime.hour, minutes: startTime.minute).inSeconds,
          bookingEndduration:
          Duration(hours: endTime.hour, minutes: endTime.minute).inSeconds,
          bookingUserId: Global.activeCustomer.customerId,
          // todo need to use unique id during login
          bookingId: uuid.v4(),
          bookingStatus: false,
        ));




  }

  void _handlePaymentError(PaymentFailureResponse response) {
    print(
        "code is ${response.code.toString()} response${response.message.toString()}");
    Fluttertoast.showToast(
        msg: "ERROR: " + response.code.toString() + " - " + response.message,
        timeInSecForIosWeb: 4);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    Fluttertoast.showToast(
        msg: "EXTERNAL_WALLET: " + response.walletName, timeInSecForIosWeb: 4);
  }
}
