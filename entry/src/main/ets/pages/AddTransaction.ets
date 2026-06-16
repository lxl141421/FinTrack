
import { router } from '@kit.ArkUI'
import { Transaction } from '../models/Transaction'
import { Category } from '../models/Category'
import { StorageService } from '../services/StorageService'
import { DistributedService } from '../services/DistributedService'
import { NotificationService } from '../services/NotificationService'
import { Constants } from '../constants/Constants'
import { CurrencyUtils } from '../utils/CurrencyUtils'
import { DateUtils } from '../utils/DateUtils'
import { Validator, ValidationResult } from '../utils/Validator'
import { ErrorHandler, ErrorType } from '../utils/ErrorHandler'
import { ThemeFont, ThemeRadius, ThemeSpacing, ThemeManager, ThemeAnimation } from '../theme/Theme'
import { hilog } from '@kit.PerformanceAnalysisKit'
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
  @State amountError: string = ''
  @State categoryError: string = ''
  @State noteError: string = ''

  private storageService = StorageService.getInstance()
  private distributedService = DistributedService.getInstance()
  private notificationService = NotificationService.getInstance()
  private themeManager = ThemeManager.getInstance()

  aboutToAppear(): void {
    this.categories = Category.getDefaults().filter(c => c.type === this.selectedType)
  }

  private switchType(type: number): void {
    this.selectedType = type
    this.selectedCategory = ''
    this.selectedCategoryName = ''
    this.categories = Category.getDefaults().filter(c => c.type === type)
    this.categoryError = ''
  }

  /**
   * 实时验证金额输入
   */
  private validateAmountField(value: string): void {
    if (value === '') {
      this.amountError = ''
      return
    }
    const result = Validator.validateAmount(value)
    this.amountError = result.valid ? '' : result.errorMessage
  }

  /**
   * 验证备注输入
   */
  private validateNoteField(value: string): void {
    const result = Validator.validateAndSanitizeNote(value)
    this.noteError = result.valid ? '' : result.errorMessage
  }

  /**
   * 验证所有字段并提交
   */
  private async submit(): Promise<void> {
    // 清除之前的错误
    this.amountError = ''
    this.categoryError = ''
    this.noteError = ''

    // 验证金额
    const amountResult = Validator.validateAmount(this.amount)
    if (!amountResult.valid) {
      this.amountError = amountResult.errorMessage
      promptAction.showToast({ message: amountResult.errorMessage })
      return
    }

    // 验证分类
    const catResult = Validator.validateCategory(this.selectedCategory, this.selectedCategoryName)
    if (!catResult.valid) {
      this.categoryError = catResult.errorMessage
      promptAction.showToast({ message: catResult.errorMessage })
      return
    }

    // 验证备注
    const noteResult = Validator.validateAndSanitizeNote(this.note)
    if (!noteResult.valid) {
      this.noteError = noteResult.errorMessage
      promptAction.showToast({ message: noteResult.errorMessage })
      return
    }

    // 验证日期
    const dateResult = Validator.validateDateRange(this.selectedDate, Date.now())
    if (!dateResult.valid) {
      promptAction.showToast({ message: dateResult.errorMessage })
      return
    }

    this.isSubmitting = true

    try {
      // 清理输入防注入
      const sanitizedNote = Validator.sanitizeInput(this.note)
      const txn = Transaction.create(
        this.selectedType,
        Number(this.amount),
        this.selectedCategory,
        this.selectedCategoryName,
        sanitizedNote,
        this.selectedDate
      )

      await this.storageService.insertTransaction(txn)

      // 分布式同步（失败不影响主流程）
      try {
        await this.distributedService.putTransaction(txn)
      } catch (syncErr) {
        ErrorHandler.handle(syncErr as Object, ErrorType.SYNC, '分布式同步')
      }

      // 大额交易通知提醒（≥500元）
      try {
        if (txn.amount >= 500) {
          await this.notificationService.sendLargeTransactionAlert(
            txn.amount,
            txn.categoryName,
            txn.type === Constants.TYPE_EXPENSE
          )
        }
      } catch (notifyErr) {
        hilog.warn(0x0000, 'FinTrack', 'Large txn notification failed: %{public}s',
          JSON.stringify(notifyErr))
      }

      promptAction.showToast({ message: '记录成功！' })
      router.back()
    } catch (err) {
      ErrorHandler.handleWithToast(err as Object, ErrorType.DATABASE, '保存交易记录')
    } finally {
      this.isSubmitting = false
    }
  }

  build() {
    Column() {
      // 顶部类型选择（带滑动手势切换）
      Row({ space: ThemeSpacing.sm }) {
        this.buildTypeButton('支出', Constants.TYPE_EXPENSE, '#FA2A2D')
        this.buildTypeButton('收入', Constants.TYPE_INCOME, '#00B578')
        this.buildTypeButton('转账', Constants.TYPE_TRANSFER, '#007DFF')
      }
      .width('100%')
      .padding(ThemeSpacing.lg)
      .gesture(
        PanGesture({ direction: PanDirection.Horizontal })
          .onActionEnd((event: GestureEvent) => {
            if (event.offsetX < -50) {
              // 左滑：切换到下一个类型
              if (this.selectedType === Constants.TYPE_EXPENSE) this.switchType(Constants.TYPE_INCOME)
              else if (this.selectedType === Constants.TYPE_INCOME) this.switchType(Constants.TYPE_TRANSFER)
            } else if (event.offsetX > 50) {
              // 右滑：切换到上一个类型
              if (this.selectedType === Constants.TYPE_TRANSFER) this.switchType(Constants.TYPE_INCOME)
              else if (this.selectedType === Constants.TYPE_INCOME) this.switchType(Constants.TYPE_EXPENSE)
            }
          })
      )

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
              this.validateAmountField(value)
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Bottom)

        // 金额错误提示
        if (this.amountError !== '') {
          Text(this.amountError)
            .fontSize(ThemeFont.xs)
            .fontColor('#FA2A2D')
            .width('100%')
        }
      }
      .width('100%')
      .padding(ThemeSpacing.xl)

      Divider()

      // 分类选择
      Column({ space: ThemeSpacing.md }) {
        Row() {
          Text('选择分类')
            .fontSize(ThemeFont.md)
            .fontWeight(ThemeFont.weightMedium)
            .fontColor('#181818')
          if (this.categoryError !== '') {
            Text(` (${this.categoryError})`)
              .fontSize(ThemeFont.xs)
              .fontColor('#FA2A2D')
          }
        }
        .alignSelf(ItemAlign.Start)
        .padding({ left: ThemeSpacing.lg })

        Flex({ wrap: FlexWrap.Wrap }) {
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
              color: this.selectedCategory === cat.id ? '#007DFF' :
                (this.categoryError !== '' ? '#FA2A2D' : '#E5E5E5')
            })
            .onClick(() => {
              this.selectedCategory = cat.id
              this.selectedCategoryName = cat.name
              this.categoryError = ''
            })
          })
        }
        .width('100%')
        .padding({ left: ThemeSpacing.lg, right: ThemeSpacing.lg })
      }
      .padding({ top: ThemeSpacing.lg })

      // 备注输入
      Column({ space: 2 }) {
        TextInput({ placeholder: '添加备注...', text: this.note })
          .width('100%')
          .height(44)
          .margin(ThemeSpacing.lg)
          .borderRadius(ThemeRadius.sm)
          .backgroundColor(this.themeManager.isDark ? '#2C2C2C' : '#F8F9FA')
          .border({ width: this.noteError !== '' ? 1 : 0, color: '#FA2A2D' })
          .onChange((value: string) => {
            this.note = value
            this.validateNoteField(value)
          })

        if (this.noteError !== '') {
          Text(this.noteError)
            .fontSize(ThemeFont.xs)
            .fontColor('#FA2A2D')
            .padding({ left: ThemeSpacing.lg })
        }
      }

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
    .backgroundColor(this.themeManager.isDark ? '#121212' : '#FFFFFF')
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
