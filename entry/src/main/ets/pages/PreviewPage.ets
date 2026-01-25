import { Account, DirectoryEntry, Logger } from 'nextcloud';
import { Path } from '../utils/Path';

const TAG: string = "Page-PreviewPage";

export let PREVIEW_PAGE_NAME: string = "PreviewPage";


@ComponentV2
struct PreviewPage {
    @Require @Param account: Account;
    @Require @Param entry: DirectoryEntry;
    @Require @Param fullPath: Path = new Path();
    @Local private previewLoaded: boolean = false;
    @Local private previewLink: string = this.account.getPreviewUrl(this.entry.fileId, 100, 100);
    @Local private previewLevel: number = 0;
    @Local private failedToLoad: boolean = false;
    @Local private failedReason: string = "";
    @Local private title: string = "";
    // Zoom and Pan states
    @Local private imageScale: number = 1;
    @Local private offsetX: number = 0;
    @Local private offsetY: number = 0;
    @Local private eventOffsetX: number = 0;
    @Local private eventOffsetY: number = 0;
    @Local private previousScale: number = 1;
    //
    private startPinchX: number = 0;
    private startPinchY: number = 0;

    @Monitor('previewLevel')
    onPreviewLevelChanged() {
        Logger.Info(TAG, "Preview level: " + this.previewLevel);
        if (this.previewLevel == 4) {
            this.previewLoaded = true;
        }
    }

    aboutToAppear(): void {
        Logger.Info(TAG, "PreviewPage about to appear for file ID: " + this.entry.fileId);
        this.title = this.fullPath.parentName + "/" + this.entry.name;
    }

    build() {
        NavDestination() {
            Stack() {
                Image(this.previewLink)
                    .onComplete(() => {
                        this.previewLevel++;

                        if (this.previewLevel == 2) {
                            Logger.Info(TAG, "Preview image loaded, start loading full image");
                            if (this.entry.mime.startsWith("image/")) {
                                this.previewLink = this.account.getDownloadUrl(this.fullPath.path(false));
                            } else {
                                this.previewLink = this.account.getPreviewUrl(this.entry.fileId, 1000, 1000);
                            }
                        }
                    })
                    .onError((e) => {
                        Logger.Error(TAG, "Failed to load preview image: " + e.message);
                        this.failedReason = e.message;
                        this.failedToLoad = true;
                    })
                    .draggable(this.previewLoaded)
                    .objectFit(ImageFit.Contain)
                    .scale({ x: this.imageScale, y: this.imageScale })
                    .offset({
                        x: this.offsetX * this.imageScale + this.eventOffsetX,
                        y: this.offsetY * this.imageScale + this.eventOffsetY,
                    })
                    .dynamicRangeMode(DynamicRangeMode.HIGH)
                    .gesture(
                        GestureGroup(GestureMode.Parallel,
                            PanGesture()
                                .onActionStart((_event: GestureEvent) => {
                                })
                                .onActionUpdate((event: GestureEvent) => {
                                    this.eventOffsetX = event.offsetX * this.imageScale;
                                    this.eventOffsetY = event.offsetY * this.imageScale;
                                })
                                .onActionEnd((_event: GestureEvent) => {
                                    this.offsetX = this.offsetX + this.eventOffsetX / this.imageScale;
                                    this.offsetY = this.offsetY + this.eventOffsetY / this.imageScale;
                                    this.eventOffsetX = 0;
                                    this.eventOffsetY = 0;
                                }),
                            PinchGesture()
                                .onActionStart((_event: GestureEvent) => {
                                    this.previousScale = this.imageScale;
                                    this.startPinchX = _event.pinchCenterX;
                                    this.startPinchY = _event.pinchCenterY;
                                })
                                .onActionUpdate((event: GestureEvent) => {
                                    this.eventOffsetX = (event.pinchCenterX - this.startPinchX) * this.previousScale;
                                    this.eventOffsetY = (event.pinchCenterY - this.startPinchY) * this.previousScale;
                                    this.imageScale = this.previousScale * event.scale;
                                })
                                .onActionEnd((_event: GestureEvent) => {
                                    this.offsetX = (this.offsetX * this.imageScale + this.eventOffsetX) / this.imageScale;
                                    this.offsetY = (this.offsetY * this.imageScale + this.eventOffsetY) / this.imageScale;
                                    this.eventOffsetX = 0;
                                    this.eventOffsetY = 0;
                                }),
                        )
                    )
                    .width('100%')
                    .height('100%')

                LoadingProgress()
                    .layoutWeight(1)
                    .width('10%')
                    .enableLoading(!this.failedToLoad)
                    .visibility(this.previewLoaded ? Visibility.Hidden : Visibility.Visible)

                Text("Failed to load preview image\n" + this.failedReason)
                    .visibility(this.failedToLoad ? Visibility.Visible : Visibility.Hidden)
                    .width('100%')
                    .textAlign(TextAlign.Center)
                    .fontColor(Color.Gray)
            }
            .width('100%')
            .height('100%')
        }
        .title(this.title)
    }
}

export interface PreviewPageProps {
    entry: DirectoryEntry;
    fullPath: Path;
    account: Account;
}

@Builder
export function PreviewPageBuilder(_name: string, props: PreviewPageProps) {
    PreviewPage({ account: props.account, entry: props.entry, fullPath: props.fullPath });
}
