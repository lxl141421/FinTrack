
import { router } from '@kit.ArkUI'
import { Transaction } from '../models/Transaction'
import { Category } from '../models/Category'
import { StorageService } from '../services/StorageService'
import { DistributedService } from '../services/DistributedService'
import { Constants } from '../constants/Constants'
import { CurrencyUtils } from '../utils/CurrencyUtils'
import { DateUtils } from '../utils/DateUtils'
import { ThemeFont, ThemeRadius, ThemeSpacing } from '../theme/Theme'
import { promptAction } from '@kit.ArkUI'

@Entry
@Component
struct AddTransaction {
  @State selectedType: number = Constants.TYPE_EXPENSE
  @State amount: string = ''
  @State selectedCategory: string = ''
  @State selectedCategoryName: string = ''
  @State note: string = ''
  @State selectedDate: number = Date.now()
  @State categories: Category[] = []
  @State showDatePicker: boolean = false
  @State isSubmitting: boolean = false

  private storageService = StorageService.getInstance()
  private distributedService = DistributedService.getInstance()

  aboutToAppear(): void {
    this.categories = Category.getDefaults().filter(c => c.type === this.selectedType)
  }

  private switchType(type: number): void {
    this.selectedType = type
    this.selectedCategory = ''
    this.selectedCategoryName = ''
    this.categories = Category.getDefaults().filter(c => c.type === type)
  }

  private async submit(): Promise<void> {
    if (this.amount === '' || Number(this.amount) <= 0) {
      promptAction.showToast({ message: '请输入金额' })
      return
    }
    if (this.selectedCategory === '') {
      promptAction.showToast({ message: '请选择分类' })
      return
    }

    this.isSubmitting = true

    try {
      const txn = Transaction.create(
        this.selectedType,
        Number(this.amount),
        this.selectedCategory,
        this.selectedCategoryName,
        this.note,
        this.selectedDate
      )

      await this.storageService.insertTransaction(txn)
      await this.distributedService.putTransaction(txn)

      promptAction.showToast({ message: '记录成功！' })
      router.back()
    } catch (err) {
      promptAction.showToast({ message: '保存失败，请重试' })
    } finally {
      this.isSubmitting = false
    }
  }

  build() {
    Column() {
      // 顶部类型选择
      Row({ space: ThemeSpacing.sm }) {
        this.buildTypeButton('支出', Constants.TYPE_EXPENSE, '#FA2A2D')
        this.buildTypeButton('收入', Constants.TYPE_INCOME, '#00B578')
        this.buildTypeButton('转账', Constants.TYPE_TRANSFER, '#007DFF')
      }
      .width('100%')
      .padding(ThemeSpacing.lg)

      // 金额输入
      Column({ space: ThemeSpacing.sm }) {
        Text(this.selectedType === Constants.TYPE_EXPENSE ? '支出金额' :
          this.selectedType === Constants.TYPE_INCOME ? '收入金额' : '转账金额')
          .fontSize(ThemeFont.sm)
          .fontColor('#999')

        Row() {
          Text(CurrencyUtils.getSymbol('CNY'))
            .fontSize(ThemeFont.display)
            .fontWeight(ThemeFont.weightBold)
            .fontColor('#181818')

          TextInput({ placeholder: '0.00', text: this.amount })
            .fontSize(ThemeFont.display)
            .fontWeight(ThemeFont.weightBold)
            .type(InputType.Number)
            .backgroundColor('transparent')
            .layoutWeight(1)
            .onChange((value: string) => {
              this.amount = value
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Bottom)
      }
      .width('100%')
      .padding(ThemeSpacing.xl)

      Divider()

      // 分类选择
      Column({ space: ThemeSpacing.md }) {
        Text('选择分类')
          .fontSize(ThemeFont.md)
          .fontWeight(ThemeFont.weightMedium)
          .fontColor('#181818')
          .alignSelf(ItemAlign.Start)
          .padding({ left: ThemeSpacing.lg })

        Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
          ForEach(this.categories, (cat: Category) => {
            Column({ space: 4 }) {
              Text(cat.icon)
                .fontSize(28)
              Text(cat.name)
                .fontSize(ThemeFont.xs)
                .fontColor(this.selectedCategory === cat.id ? '#007DFF' : '#666')
            }
            .width(72)
            .height(72)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(this.selectedCategory === cat.id ? '#007DFF15' : '#F8F9FA')
            .borderRadius(ThemeRadius.md)
            .border({
              width: this.selectedCategory === cat.id ? 2 : 1,
              color: this.selectedCategory === cat.id ? '#007DFF' : '#E5E5E5'
            })
            .onClick(() => {
              this.selectedCategory = cat.id
              this.selectedCategoryName = cat.name
            })
          })
        }
        .width('100%')
        .padding({ left: ThemeSpacing.lg, right: ThemeSpacing.lg })
      }
      .padding({ top: ThemeSpacing.lg })

      // 备注输入
      TextInput({ placeholder: '添加备注...', text: this.note })
        .width('100%')
        .height(44)
        .margin(ThemeSpacing.lg)
        .borderRadius(ThemeRadius.sm)
        .backgroundColor('#F8F9FA')
        .onChange((value: string) => {
          this.note = value
        })

      // 日期选择
      Row() {
        Text('日期')
          .fontSize(ThemeFont.md)
          .fontColor('#181818')
        Blank()
        Text(DateUtils.format(this.selectedDate, 'YYYY-MM-DD'))
          .fontSize(ThemeFont.md)
          .fontColor('#007DFF')
      }
      .width('100%')
      .padding(ThemeSpacing.lg)
      .onClick(() => {
        this.showDatePicker = true
      })

      Blank()

      // 提交按钮
      Button(this.isSubmitting ? '保存中...' : '保存')
        .width('90%')
        .height(50)
        .fontSize(ThemeFont.lg)
        .fontWeight(ThemeFont.weightMedium)
        .borderRadius(ThemeRadius.lg)
        .backgroundColor(this.selectedType === Constants.TYPE_EXPENSE ? '#FA2A2D' :
          this.selectedType === Constants.TYPE_INCOME ? '#00B578' : '#007DFF')
        .enabled(!this.isSubmitting)
        .onClick(() => {
          this.submit()
        })
        .margin({ bottom: ThemeSpacing.xxl })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }

  @Builder
  buildTypeButton(label: string, type: number, color: string) {
    Text(label)
      .fontSize(ThemeFont.md)
      .fontColor(this.selectedType === type ? '#FFFFFF' : color)
      .fontWeight(ThemeFont.weightMedium)
      .padding({
        left: ThemeSpacing.xl,
        right: ThemeSpacing.xl,
        top: ThemeSpacing.sm,
        bottom: ThemeSpacing.sm
      })
      .backgroundColor(this.selectedType === type ? color : color + '15')
      .borderRadius(ThemeRadius.full)
      .onClick(() => {
        this.switchType(type)
      })
  }
}
