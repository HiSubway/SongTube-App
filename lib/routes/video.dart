import 'dart:async';
import 'dart:io';
import 'package:circular_check_box/circular_check_box.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:songtube/internal/languages.dart';
import 'package:songtube/internal/models/metadata.dart';
import 'package:songtube/players/youtubePlayer.dart';
import 'package:songtube/provider/configurationProvider.dart';
import 'package:songtube/provider/downloadsProvider.dart';
import 'package:songtube/provider/managerProvider.dart';
import 'package:songtube/provider/preferencesProvider.dart';
import 'package:songtube/routes/components/relatedVideosList.dart';
import 'package:songtube/routes/components/video/shimmer/shimmerArtworkEditor.dart';
import 'package:songtube/routes/components/video/shimmer/shimmerVideoComments.dart';
import 'package:songtube/routes/components/video/shimmer/shimmerVideoEngagement.dart';
import 'package:songtube/routes/components/video/videoDownloadFab.dart';
import 'package:songtube/routes/components/video/videoTags.dart';
import 'package:songtube/routes/components/video/videoComments.dart';
import 'package:songtube/screens/homeScreen/downloadMenu/downloadMenu.dart';
import 'package:songtube/ui/animations/fadeIn.dart';
import 'package:songtube/ui/components/measureSize.dart';
import 'package:songtube/ui/internal/snackbar.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'components/video/videoDetails.dart';
import 'components/video/videoEngagement.dart';

class YoutubePlayerVideoPage extends StatefulWidget {
  final String url;
  final String thumbnailUrl;
  YoutubePlayerVideoPage({
    @required this.url,
    @required this.thumbnailUrl,
  });

  @override
  _YoutubePlayerVideoPageState createState() => _YoutubePlayerVideoPageState();
}

class _YoutubePlayerVideoPageState extends State<YoutubePlayerVideoPage> {

  GlobalKey<ScaffoldState> scaffoldKey;
  double playerSize;

  bool showPlayer = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 500), () =>
      setState(() => showPlayer = true));
    scaffoldKey = GlobalKey<ScaffoldState>();
    KeyboardVisibility.onChange.listen((bool visible) {
        if (visible == false) FocusScope.of(context).requestFocus(new FocusNode());
      }
    );
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    DownloadsProvider downloadsProvider = Provider.of<DownloadsProvider>(context);
    ManagerProvider manager = Provider.of<ManagerProvider>(context);
    PreferencesProvider prefs = Provider.of<PreferencesProvider>(context);
    return WillPopScope(
      onWillPop: () {
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarIconBrightness:
              Theme.of(context).brightness ==
                Brightness.dark ?  Brightness.light : Brightness.dark,
          ),
        );
        manager.youtubeExtractor.killIsolates();
        return Future.value(true);
      },
      child: Scaffold(
        key: scaffoldKey,
        body: FadeInTransition(
          duration: Duration(milliseconds: 400),
          child: Column(
            children: <Widget> [
              // Top StatusBar Padding
              Container(
                color: Colors.black,
                height: MediaQuery.of(context).padding.top,
                width: double.infinity,
              ),
              // Mini-Player
              AspectRatio(
                aspectRatio: 16/9,
                child: Hero(
                  tag: "${widget.url}player",
                  child: MeasureSize(
                    onChange: (size) {
                      playerSize = size.height;
                    },
                    child: Container(
                      color: Colors.black,
                      child: AnimatedSwitcher(
                        duration: Duration(milliseconds: 400),
                        child: showPlayer
                          ? StreamManifestPlayer(
                              manifest: manager.mediaInfoSet.streamManifest,
                              onVideoEnded: () {
                                manager.streamPlayerAutoPlay();
                              },
                            )
                          : Image.network(widget.thumbnailUrl)
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: Duration(milliseconds: 300),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    physics: BouncingScrollPhysics(),
                    children: [
                      SizedBox(height: 12),
                      // Video Details
                      VideoDetails(
                        title: manager.mediaInfoSet.videoFromSearch.videoTitle,
                        author: manager.mediaInfoSet.videoFromSearch.videoAuthor,
                        duration: manager.mediaInfoSet.videoDetails != null
                          ? manager.mediaInfoSet.videoDetails.duration.inMinutes.remainder(60).toString().padLeft(2, '0') + " min "
                            + manager.mediaInfoSet.videoDetails.duration.inSeconds.remainder(60).toString().padLeft(2, '0') + " sec"
                          : null,
                        date: manager.mediaInfoSet.videoDetails != null
                          ? "${manager.mediaInfoSet.videoDetails.uploadDate.year}/" +
                            "${manager.mediaInfoSet.videoDetails.uploadDate.month}/" +
                            "${manager.mediaInfoSet.videoDetails.uploadDate.day}"
                          : null,
                        channelLogo: manager.mediaInfoSet.channelDetails != null
                          ? manager.mediaInfoSet.channelDetails.logoUrl : null
                      ),
                      // ---------------------------------------
                      // Likes, dislikes, Views and Share button
                      // ---------------------------------------
                      AnimatedSwitcher(
                        duration: Duration(milliseconds: 300),
                        child: manager.mediaInfoSet.videoDetails != null
                          ? ListView(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              physics: NeverScrollableScrollPhysics(),
                              children: [
                                SizedBox(height: 12),
                                VideoEngagement(
                                  likeCount: manager.mediaInfoSet.videoDetails.engagement.likeCount,
                                  dislikeCount: manager.mediaInfoSet.videoDetails.engagement.dislikeCount,
                                  viewCount: manager.mediaInfoSet.videoDetails.engagement.viewCount,
                                  videoUrl: manager.mediaInfoSet.videoDetails.url,
                                  onSaveToFavorite: () {
                                    List<Video> videos = prefs.favoriteVideos;
                                    videos.add(manager.mediaInfoSet.videoDetails);
                                    prefs.favoriteVideos = videos;
                                    AppSnack.showSnackBar(
                                      icon: EvaIcons.heartOutline,
                                      title: "Video added to Favorites",
                                      context: context,
                                      scaffoldKey: scaffoldKey.currentState
                                    );
                                  },
                                ),
                                // Comments
                                /*Divider(),
                                InkWell(
                                  onTap: () {
                                    double topPadding = MediaQuery.of(context).padding.top;
                                    scaffoldKey.currentState.showBottomSheet((context) {
                                      return VideoComments(
                                        video: manager.mediaInfoSet.videoDetails,
                                        topPadding: topPadding + playerSize,
                                      );
                                    });
                                  },
                                  child: Ink(
                                    height: 60,
                                    width: double.infinity,
                                    padding: EdgeInsets.only(left: 16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Icon(EvaIcons.messageCircleOutline,
                                          color: Theme.of(context).iconTheme.color),
                                        SizedBox(width: 8),
                                        Text(
                                          "Comments",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w400,
                                            fontSize: 15,
                                          ),
                                        ),
                                        Spacer(),
                                        Icon(EvaIcons.chevronDownOutline,
                                          color: Theme.of(context).iconTheme.color),
                                        SizedBox(width: 16)
                                      ],
                                    ),
                                  ),
                                ),*/
                                Divider(),
                                // Tags Editor
                                VideoTags(
                                  tagsControllers: manager.mediaInfoSet.mediaTags,
                                  onArtworkTap: () async {
                                    File image = File((await FilePicker.platform
                                      .pickFiles(type: FileType.image))
                                      .paths[0]);
                                    if (image == null) return;
                                    manager.mediaInfoSet.mediaTags
                                      .artworkController = image.path;
                                    setState(() {});
                                  },
                                  artworkUrl: manager.mediaInfoSet.mediaTags.artworkController
                                ),
                                Divider(),
                                SizedBox(height: 8),
                                Container(
                                  margin: EdgeInsets.only(bottom: 12),
                                  height: 20,
                                  child: Row(
                                    children: [
                                      SizedBox(width: 16),
                                      Text(
                                        "Related",
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Theme.of(context).textTheme.bodyText1.color,
                                          fontFamily: 'YTSans'
                                        ),
                                        textAlign: TextAlign.left,
                                      ),
                                      SizedBox(width: 8),
                                      AnimatedSwitcher(
                                        duration: Duration(milliseconds: 300),
                                        child: manager.mediaInfoSet.relatedVideos.isEmpty
                                          ? SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 1,
                                              )
                                            )
                                          : Container()
                                      ),
                                      Spacer(),
                                      Text(
                                        "AutoPlay",
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Theme.of(context).textTheme.bodyText1.color,
                                          fontFamily: 'YTSans'
                                        ),
                                        textAlign: TextAlign.left,
                                      ),
                                      CircularCheckBox(
                                        activeColor: Theme.of(context).accentColor,
                                        value: manager.youtubePlayerAutoPlay,
                                        onChanged: (bool value) {
                                          manager.youtubePlayerAutoPlay = value;
                                        }
                                      ),
                                      SizedBox(width: 4)
                                    ],
                                  ),
                                ),
                                AnimatedSwitcher(
                                  duration: Duration(milliseconds: 300),
                                  child: manager.mediaInfoSet.relatedVideos.isNotEmpty
                                    ? RelatedVideosList(
                                        relatedVideos: manager.mediaInfoSet.relatedVideos,
                                        onVideoTap: (index) {
                                          manager.updateMediaInfoSet(
                                            manager.mediaInfoSet.relatedVideos[index]
                                          );
                                        },
                                      )
                                    : Container(),
                                )
                              ],
                            )
                          : ListView(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              physics: NeverScrollableScrollPhysics(),
                              children: [
                                SizedBox(height: 12),
                                const ShimmerVideoEngagement(),
                                Divider(color: Colors.transparent),
                                const ShimmerVideoComments(),
                                Divider(color: Colors.transparent),
                                const ShimmerArtworkEditor(),
                                Divider(color: Colors.transparent),
                              ],
                            )
                      ),
                    ],
                  ),
                ),
              ),
            ]
          ),
        ),
        floatingActionButton: VideoDownloadFab(
          readyToDownload: manager.mediaInfoSet.streamManifest == null ? false : true,
          onDownload: () async {
            FocusScope.of(context).requestFocus(new FocusNode());
            List<dynamic> response = await showModalBottomSheet<dynamic>(
              isScrollControlled: true,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30)
                ),
              ),
              clipBehavior: Clip.antiAlias,
              context: context,
              builder: (context) {
                return Wrap(
                  children: [
                    DownloadMenu(
                      videoList: manager.mediaInfoSet.streamManifest.videoOnly
                        .sortByVideoQuality(),
                      audioList: manager.mediaInfoSet.streamManifest.audioOnly
                        .sortByBitrate(),
                      audioSize: manager.mediaInfoSet.streamManifest.audioOnly
                        .withHighestBitrate().size.totalMegaBytes,
                    ),
                  ],
                );
              }
            );
            if (response == null) return;
            downloadsProvider.handleVideoDownload(
              language: Languages.of(context),
              config: Provider.of<ConfigurationProvider>(context, listen: false),
              metadata: DownloadMetaData(
                title: manager.mediaInfoSet.mediaTags.titleController.text,
                album: manager.mediaInfoSet.mediaTags.albumController.text,
                artist: manager.mediaInfoSet.mediaTags.artistController.text
                  .replaceAll("- Topic", "").trim(),
                genre: manager.mediaInfoSet.mediaTags.genreController.text,
                coverurl: manager.mediaInfoSet.mediaTags.artworkController,
                date: manager.mediaInfoSet.mediaTags.dateController.text,
                disc: manager.mediaInfoSet.mediaTags.discController.text,
                track: manager.mediaInfoSet.mediaTags.trackController.text
              ),
              manifest: manager.mediaInfoSet.streamManifest,
              videoDetails: manager.mediaInfoSet.videoDetails,
              data: response
            );
            Navigator.of(context).pop();
            await Future.delayed(Duration(milliseconds: 400));
            manager.screenIndex = 1;
          },
        ),
      ),
    );
  }
}