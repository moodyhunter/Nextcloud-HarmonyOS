import { TransferTask, TransferType } from 'nextcloud';
import { LengthMetrics } from '@kit.ArkUI';

@Component
struct TransferProgressItem {
    @ObjectLink transferTask: TransferTask;

    build() {
        Column({ space: 4 }) {
            Text(this.transferTask.filename)
                .textOverflow({ overflow: TextOverflow.MARQUEE })
                .textAlign(TextAlign.Start)
                .width('100%')

            Progress({
                value: this.transferTask.transferredSize,
                total: this.transferTask.totalSize,
            })
                .flexGrow(1)

            Text(this.transferTask.progressPercentText)
            // .flexBasis()
        }
        .backgroundColor($r('sys.color.ohos_id_color_hover'))
        .padding(8)
        .borderRadius(4)
        .width('100%')
    }
}

@Entry
@Component
struct StatusBarPage {
    @State tasks: TransferTask[] = [];

    aboutToAppear(): void {
        for (let i = 0; i < 80; i++) {
            this.tasks.push(new TransferTask(TransferType.DOWNLOAD, `file name ${i}`));
        }
    }

    onPageShow(): void {
        for (let task of this.tasks) {
            let total = Math.random() * 10000;
            let transferred = Math.random() * total;
            task.updateProgress(transferred, total);
        }

        if (false) {
            setInterval(() => {
                for (let task of this.tasks) {
                    let transferred = Math.random() * task.totalSize;
                    task.updateProgress(transferred, task.totalSize);
                }
            }, 1000);
        }
    }

    build() {
        Scroll() {
            Column({ space: 16 }) {
                ForEach(this.tasks, (item: TransferTask) => {
                    TransferProgressItem({
                        transferTask: item
                    })
                })
            }
        }
        .padding(16)
        .width('100%')
        .height('100%')
    }
}
