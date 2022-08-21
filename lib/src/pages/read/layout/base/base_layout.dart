import 'dart:math';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../model/gallery_image.dart';
import '../../../../service/gallery_download_service.dart';
import '../../../../utils/log.dart';
import '../../../../utils/route_util.dart';
import '../../../../widget/eh_image.dart';
import '../../../../widget/icon_text_button.dart';
import '../../../../widget/loading_state_indicator.dart';
import '../../read_page_logic.dart';
import '../../read_page_state.dart';
import 'base_layout_logic.dart';
import 'base_layout_state.dart';

abstract class BaseLayout extends StatelessWidget {
  BaseLayout({Key? key}) : super(key: key);

  final ReadPageLogic readPageLogic = Get.find<ReadPageLogic>();
  final ReadPageState readPageState = Get.find<ReadPageLogic>().state;

  final GalleryDownloadService downloadService = Get.find();

  BaseLayoutLogic get logic;

  BaseLayoutState get state;

  /// online mode: parsing and loading automatically while scrolling
  Widget buildItemInOnlineMode(BuildContext context, int index) {
    return GetBuilder<ReadPageLogic>(
      id: '${readPageLogic.onlineImageId}::$index',
      builder: (_) {
        /// step 1: parse image href if needed. check if thumbnail's info exists, if not, [parse] one page of thumbnails to get image hrefs.
        if (readPageState.thumbnails[index] == null) {
          if (readPageState.parseImageHrefsState == LoadingState.idle) {
            readPageLogic.beginToParseImageHref(index);
          }
          return _buildParsingHrefsIndicator(context, index);
        }

        /// step 2: parse image url.
        if (readPageState.images[index] == null) {
          if (readPageState.parseImageUrlStates[index] == LoadingState.idle) {
            readPageLogic.beginToParseImageUrl(index, false);
          }
          return _buildParsingUrlIndicator(context, index);
        }

        /// step 3: use url to load image
        FittedSizes fittedSizes = logic.getImageFittedSize(readPageState.images[index]!);
        return EHImage.network(
          containerHeight: fittedSizes.destination.height,
          containerWidth: fittedSizes.destination.width,
          galleryImage: readPageState.images[index]!,
          adaptive: true,
          fit: BoxFit.contain,
          loadingWidgetBuilder: (double progress) => _loadingWidgetBuilder(context, index, progress),
          failedWidgetBuilder: (ExtendedImageState state) => _failedWidgetBuilder(context, index, state),
        );
      },
    );
  }

  /// local mode: wait for download service to parse and download
  Widget buildItemInLocalMode(BuildContext context, int index) {
    return GetBuilder<GalleryDownloadService>(
      id: '$downloadImageId::${readPageState.readPageInfo.gid}',
      builder: (_) {
        /// step 1: wait for parsing image's href for this image. But if image's url has been parsed,
        /// we don't need to wait parsing thumbnail.
        if (readPageState.thumbnails[index] == null && readPageState.images[index] == null) {
          return _buildWaitParsingHrefsIndicator(context, index);
        }

        /// step 2: wait for parsing image's url.
        if (readPageState.images[index] == null) {
          return _buildWaitParsingUrlIndicator(context, index);
        }

        /// step 3: use url to load image
        FittedSizes fittedSizes = logic.getImageFittedSize(readPageState.images[index]!);
        return EHImage.file(
          containerHeight: fittedSizes.destination.height,
          containerWidth: fittedSizes.destination.width,
          galleryImage: readPageState.images[index]!,
          adaptive: true,
          fit: BoxFit.contain,
          downloadingWidgetBuilder: () => _downloadingWidgetBuilder(index),
          pausedWidgetBuilder: () => _pausedWidgetBuilder(index),
        );
      },
    );
  }

  /// wait for [readPageLogic] to parse image href in online mode
  Widget _buildParsingHrefsIndicator(BuildContext context, int index) {
    Size placeHolderSize = logic.getPlaceHolderSize();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => _showReParseBottomSheet(context, () => readPageLogic.beginToParseImageHref(index)),
      child: SizedBox(
        height: placeHolderSize.height,
        width: placeHolderSize.width,
        child: GetBuilder<ReadPageLogic>(
          id: readPageLogic.parseImageHrefsStateId,
          builder: (_) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LoadingStateIndicator(
                useCupertinoIndicator: false,
                loadingState: readPageState.parseImageHrefsState,
                idleWidget: const CircularProgressIndicator(),
                errorWidget: const Icon(Icons.warning, color: Colors.yellow),
              ),
              Text(
                readPageState.parseImageHrefsState == LoadingState.error ? readPageState.parseImageHrefErrorMsg! : 'parsingPage'.tr,
                style: readPageState.readPageTextStyle,
              ).marginOnly(top: 8),
              Text(index.toString(), style: readPageState.readPageTextStyle).marginOnly(top: 4),
            ],
          ),
        ),
      ),
    );
  }

  /// wait for [readPageLogic] to parse image url in online mode
  Widget _buildParsingUrlIndicator(BuildContext context, int index) {
    Size placeHolderSize = logic.getPlaceHolderSize();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => _showReParseBottomSheet(context, () => readPageLogic.beginToParseImageUrl(index, true)),
      child: SizedBox(
        height: placeHolderSize.height,
        width: placeHolderSize.width,
        child: GetBuilder<ReadPageLogic>(
          id: '${readPageLogic.parseImageUrlStateId}::$index',
          builder: (_) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LoadingStateIndicator(
                useCupertinoIndicator: false,
                loadingState: readPageState.parseImageUrlStates[index],
                idleWidget: const CircularProgressIndicator(),
                errorWidget: const Icon(Icons.warning, color: Colors.yellow),
              ),
              Text(
                readPageState.parseImageUrlStates[index] == LoadingState.error ? readPageState.parseImageUrlErrorMsg[index]! : 'parsingURL'.tr,
                style: readPageState.readPageTextStyle,
              ).marginOnly(top: 8),
              Text(index.toString(), style: readPageState.readPageTextStyle).marginOnly(top: 4),
            ],
          ),
        ),
      ),
    );
  }

  /// loading for online mode
  Widget _loadingWidgetBuilder(BuildContext context, int index, double progress) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(value: progress),
        Text('loading'.tr, style: readPageState.readPageTextStyle).marginOnly(top: 8),
        Text(index.toString(), style: readPageState.readPageTextStyle).marginOnly(top: 4),
      ],
    );
  }

  /// failed for online mode
  Widget _failedWidgetBuilder(BuildContext context, int index, ExtendedImageState state) {
    Log.warning(state.lastException);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconTextButton(
          iconData: Icons.error,
          text: Text('networkError'.tr, style: readPageState.readPageTextStyle),
          onPressed: state.reLoadImage,
        ),
        Text(index.toString(), style: readPageState.readPageTextStyle),
      ],
    );
  }

  void _showReParseBottomSheet(BuildContext context, ErrorTapCallback callback) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: Text('reload'.tr),
            onPressed: () {
              callback();
              backRoute();
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text('cancel'.tr),
          onPressed: () => backRoute(),
        ),
      ),
    );
  }

  /// wait for [GalleryDownloadService] to parse image href in local mode
  Widget _buildWaitParsingHrefsIndicator(BuildContext context, int index) {
    DownloadStatus downloadStatus = downloadService.gid2DownloadProgress[readPageState.readPageInfo.gid]!.downloadStatus;
    Size placeHolderSize = logic.getPlaceHolderSize();

    return SizedBox(
      height: placeHolderSize.height,
      width: placeHolderSize.width,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (downloadStatus == DownloadStatus.downloading) const CircularProgressIndicator(),
          if (downloadStatus == DownloadStatus.paused) const Icon(Icons.pause_circle_outline, color: Colors.white),
          Text(
            downloadStatus == DownloadStatus.downloading ? 'parsingPage'.tr : 'paused'.tr,
            style: readPageState.readPageTextStyle,
          ).marginOnly(top: 8),
          Text(index.toString(), style: readPageState.readPageTextStyle).marginOnly(top: 4),
        ],
      ),
    );
  }

  /// wait for [GalleryDownloadService] to parse image url in local mode
  Widget _buildWaitParsingUrlIndicator(BuildContext context, int index) {
    DownloadStatus downloadStatus = downloadService.gid2DownloadProgress[readPageState.readPageInfo.gid]!.downloadStatus;
    Size placeHolderSize = logic.getPlaceHolderSize();
    return SizedBox(
      height: placeHolderSize.height,
      width: placeHolderSize.width,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (downloadStatus == DownloadStatus.downloading) const CircularProgressIndicator(),
          if (downloadStatus == DownloadStatus.paused) const Icon(Icons.pause_circle_outline, color: Colors.white),
          Text(
            downloadStatus == DownloadStatus.downloading ? 'parsingURL'.tr : 'paused'.tr,
            style: readPageState.readPageTextStyle,
          ).marginOnly(top: 8),
          Text(index.toString(), style: readPageState.readPageTextStyle).marginOnly(top: 4),
        ],
      ),
    );
  }

  /// downloaded for local mode
  Widget _downloadingWidgetBuilder(int index) {
    return GetBuilder<GalleryDownloadService>(
      id: '$galleryDownloadSpeedComputerId::${readPageState.readPageInfo.gid}',
      builder: (_) {
        GalleryDownloadSpeedComputer speedComputer = downloadService.gid2SpeedComputer[readPageState.readPageInfo.gid]!;
        int downloadedBytes = speedComputer.imageDownloadedBytes[index];
        int totalBytes = speedComputer.imageBytes[index];

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(value: max(downloadedBytes / totalBytes, 0.01)),
            Text('downloading'.tr, style: readPageState.readPageTextStyle).marginOnly(top: 8),
            Text(index.toString(), style: readPageState.readPageTextStyle),
          ],
        );
      },
    );
  }

  /// paused for local mode
  Widget _pausedWidgetBuilder(int index) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.pause_circle_outline, color: Colors.white),
        Text('paused'.tr, style: readPageState.readPageTextStyle).marginOnly(top: 8),
        Text(index.toString(), style: readPageState.readPageTextStyle),
      ],
    );
  }
}