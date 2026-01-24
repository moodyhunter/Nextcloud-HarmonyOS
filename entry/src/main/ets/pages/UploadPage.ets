import { Category, Logger, PhotoAssetsManager, PhotoItem, UploadStatus } from 'nextcloud';
import { LengthMetrics } from '@kit.ArkUI';

const TAG = "Page-UploadPage"

@ComponentV2
struct PhotoView {
    @Require @Param asset: PhotoItem;
    @Require @Param category: Category;
    @Local private thumbnail: PixelMap | null = null;

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
            await this.asset.upload("/instantupload/category/");
        })
        .onAppear(async () => {
            if (this.thumbnail === null) {
                this.thumbnail = await this.asset.getThumbnail({ height: 150, width: 150 });
            }
        })
    }
}

@Preview
@ComponentV2
export struct UploadPage {
    @Local private categories: Map<number, Category> = PhotoAssetsManager.categories;

    @Builder
    photosGridView(category: Category) {
        Stack() {
            Grid() {
                LazyForEach(category.visibleItems, (asset: PhotoItem, index: number) => {
                    GridItem() {
                        PhotoView({ asset: asset, category: category })
                    }
                    .width('100%')
                    .onAppear(() => {
                        if (index == category.visibleItems.totalCount() - 1) {
                            category.loadNextBatch();
                        }
                    })
                })
            }
            .layoutDirection(GridDirection.Row)
            .fadingEdge(true, { fadingEdgeLength: LengthMetrics.vp(80) })
            // .columnsTemplate('1fr 1fr 1fr 1fr')
            .columnsTemplate('repeat(auto-fit, 100)')
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
                        Logger.Info(TAG, `Upload all in '${category.name}'`);
                        // this.category.uploadAllAssets();
                    })
                    .width('30%')
            }
            .width('100%')
            .position({ bottom: 5 })
        }
    }

    build() {
        Tabs() {
            ForEach(Array.from(this.categories), (category: [number, Category]) => {
                if (category[1].visibleItems.totalCount() >= 10) {
                    TabContent() {
                        Flex({ direction: FlexDirection.Column, space: { main: LengthMetrics.px(20) } }) {
                            Row({ space: 16 }) {
                                TextInput({ text: category[1].name })
                                    .fontWeight(FontWeight.Bold)
                                    .fontSize(24)
                                    .onChange((newValue: string) => {
                                        category[1].setAlias(newValue);
                                    })
                                    .flexShrink(1)

                                Text('category.location')
                                    .flexShrink(0)
                                    .constraintSize({ minWidth: 120 })
                            }
                            .justifyContent(FlexAlign.Center)
                            .height(60)
                            .width('100%')

                            this.photosGridView(category[1])
                        }
                        .width('100%')
                        .height('100%')
                    }
                    .margin(10)
                    .tabBar(category[1].name)
                }
            })
        }
        .vertical(true)
        .barWidth(100)
        .barMode(BarMode.Scrollable)
    }
}
