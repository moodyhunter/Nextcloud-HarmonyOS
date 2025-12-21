import { Logger, NCommon } from 'nextcloud';
import { Category } from '../models/Category';
import { LengthMetrics } from '@kit.ArkUI';
import { PhotoItem, UploadStatus } from '../models/PhotoItem';
import { UploadScheduler } from '../utils/UploadScheduler';

const TAG = "Page-UploadPage"


@Component
struct PhotoView {
    @ObjectLink asset: PhotoItem;
    @ObjectLink category: Category;
    @State private thumbnail: PixelMap | null = null;

    getUploadColor(status: UploadStatus): Color {
        switch (status) {
            case UploadStatus.Uploaded:
                return Color.Green;
            case UploadStatus.Uploading:
                return Color.Yellow;
            case UploadStatus.Failed:
                return Color.Red;
            case UploadStatus.None:
                return Color.Gray;
            case UploadStatus.Existed:
                return Color.Blue;
            default:
                return Color.Gray;
        }
    }

    build() {
        Stack() {
            Image(this.thumbnail)
                .height(100)
                .width(100)
                .objectFit(ImageFit.Cover)

            Text(this.asset.isVideo ? '▶' : '')
                .fontSize(48)
                .fontFamily('monospace')
                .fontColor(Color.Red)
        }
        .draggable(false)
        .height(100)
        .width(100)
        .borderWidth(3)
        .borderColor(this.getUploadColor(this.asset.uploadStatus))
        .onClick(async () => {
            await this.asset.upload(NCommon.Preference.baseUploadDirectory + this.category.location);
        })
        .onAppear(async () => {
            if (this.thumbnail === null) {
                this.thumbnail = await this.asset.getThumbnail({ height: 150, width: 150 });
            }
        })
    }
}

@Component
struct PhotosGridView {
    @ObjectLink category: Category;
    private scroller: Scroller = new Scroller();

    build() {
        Stack() {
            Grid(this.scroller) {
                LazyForEach(this.category.visibleItems, (asset: PhotoItem, index: number) => {
                    GridItem() {
                        PhotoView({ asset: asset, category: this.category })
                    }
                    .width('100%')
                    .onAppear(() => {
                        if (index == this.category.visibleItems.totalCount() - 1) {
                            this.category.showNext50();
                        }
                    })
                })
            }
            .fadingEdge(true, { fadingEdgeLength: LengthMetrics.vp(80) })
            .columnsTemplate('1fr 1fr 1fr 1fr')
            .scrollBar(BarState.On)
            .edgeEffect(EdgeEffect.Spring)
            .columnsGap(8)
            .rowsGap(8)
            .cachedCount(10)
            .width('100%')
            .height('auto')

            Column() {
                Button($r('app.string.upload_all'))
                    .onClick(() => {
                        Logger.Info(TAG, `Upload all in '${this.category.name}'`);
                        this.category.uploadAllAssets();
                    })
                    .width('30%')
            }
            .width('100%')
            .position({ bottom: 5 })
        }
    }
}


@Preview
@Component
export struct UploadPage {
    @State private categories: Category[] = UploadScheduler.categories;

    build() {
        Tabs() {
            ForEach(this.categories, (category: Category) => {
                TabContent() {
                    Flex({ direction: FlexDirection.Column, space: { main: LengthMetrics.px(20) } }) {
                        Flex({ direction: FlexDirection.Row, justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Baseline }) {
                            Text(category.name)
                                .fontWeight(FontWeight.Bold)
                                .fontSize(24)

                            Text(category.location)
                        }
                        .height(32)

                        ForEach(category.patterns, (pattern: string) => {
                            Text(pattern)
                                .fontSize(12)
                                .fontColor(Color.Green)
                                .fontFamily('serif')
                        })

                        PhotosGridView({ category: category })
                    }
                    .width('100%')
                    .height('100%')
                }
                .margin(10)
                .tabBar(category.name)
            })
        }
    }
}
