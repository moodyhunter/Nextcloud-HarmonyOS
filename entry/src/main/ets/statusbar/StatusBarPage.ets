import { Logger } from 'nextcloud';
import { TransferJobStatus, TransferStatusReceiver } from './TransferStatusReceiver';

const TAG = 'StatusBar/Page';

@ComponentV2
struct TransferProgressItem {
    @Require @Param task: TransferJobStatus;

    build() {
        Column({ space: 4 }) {
            Text(this.task.fileName)
                .textOverflow({ overflow: TextOverflow.MARQUEE })
                .textAlign(TextAlign.Start)
                .width('100%')

            Progress({ value: this.task.transferredSize, total: this.task.totalSize })
                .flexGrow(1)

            Text(this.task.progressPercentText)
        }
        .backgroundColor($r('sys.color.ohos_id_color_hover'))
        .padding(8)
        .borderRadius(4)
        .width('100%')
    }
}

@Entry
@ComponentV2
struct StatusBarPage {
    private statusReceiver: TransferStatusReceiver = new TransferStatusReceiver();

    aboutToAppear(): void {
        Logger.Info(TAG, `aboutToAppear`);
    }

    build() {
        Scroll() {
            Column({ space: 16 }) {
                if (this.statusReceiver) {
                    ForEach(Array.from(this.statusReceiver.tasks).reverse(), (item: [number, TransferJobStatus]) => {
                        TransferProgressItem({
                            task: item[1]
                        })
                    }, (item: [number, TransferJobStatus], _index: number) => {
                        return `${item[0]}`
                    })
                }
            }
        }
        .padding(16)
        .width('100%')
        .height('100%')
    }
}
