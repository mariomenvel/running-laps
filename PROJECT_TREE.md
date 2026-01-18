# Project Structure & Classes
Generated: 2026-01-18 22:16:18.777221

## lib\config\app_theme.dart
- [class] Tema
- [class] AvatarHelper

## lib\core\auth_failure.dart
- [class] AuthFailure

## lib\core\constants\app_help_content.dart
- [class] AppHelpContent

## lib\core\services\gps_service.dart
- [class] GpsPoint
- [enum] GpsStatus
- [class] GPSService

## lib\core\services\pdf_generator_service.dart
- [class] PdfGeneratorService

## lib\core\services\sensor_service.dart
- [enum] SensorStatus
- [class] SensorService

## lib\core\utils\kalman_filter.dart
- [class] KalmanFilter

## lib\core\utils\tag_utils.dart
- [class] TagUtils

## lib\core\widgets\app_footer.dart
- [class] AppFooter
- [class] _AppFooterState

## lib\core\widgets\app_header.dart
- [class] AppHeader

## lib\core\widgets\gradient_banner.dart
- [class] GradientBanner
- [class] _GradientBannerState
- [class] GradientChip

## lib\core\widgets\group_skeleton_card.dart
- [class] GroupSkeletonCard
- [class] _GroupSkeletonCardState

## lib\core\widgets\info_tooltip.dart
- [class] InfoTooltip

## lib\core\widgets\kpi_card_with_delta.dart
- [class] KpiCardWithDelta

## lib\core\widgets\modern_snackbar.dart
- [class] ModernSnackBar

## lib\features\admin\data\admin_repository.dart
- [class] AdminRepository

## lib\features\admin\viewmodels\admin_controller.dart
- [enum] AdminDateFilter
- [class] AdminController

## lib\features\admin\views\admin_challenges_tab.dart
- [class] AdminChallengesTab

## lib\features\admin\views\admin_dashboard_tab.dart
- [class] AdminDashboardTab

## lib\features\admin\views\admin_panel_screen.dart
- [class] AdminPanelScreen
- [class] _AdminPanelScreenState

## lib\features\analytics\data\coach_insight_service.dart
- [enum] InsightType
- [class] CoachInsight
- [class] CoachInsightService

## lib\features\analytics\data\home_config_repository.dart
- [class] HomeConfigRepository

## lib\features\analytics\data\home_layout_config.dart
- [class] HomeLayoutConfig
- [class] HomeWidget
- [enum] WidgetType
- [extension] WidgetTypeExtension

## lib\features\analytics\data\pattern_cache.dart
- [class] PatternCache

## lib\features\analytics\data\pattern_detector.dart
- [class] PatternDetector
- [class] PatternStats

## lib\features\analytics\data\series_pattern.dart
- [class] SerieInstance
- [class] SeriesPattern

## lib\features\analytics\data\workout_pattern.dart
- [class] WorkoutInstance
- [class] WorkoutPattern

## lib\features\analytics\viewmodels\analytics_hub_controller.dart
- [enum] AnalyticsTimeRange
- [class] AnalyticsHubController

## lib\features\analytics\viewmodels\analytics_viewmodel.dart
- [class] AnalyticsViewModel

## lib\features\analytics\views\analytics_hub_screen.dart
- [class] AnalyticsHubScreen
- [class] _AnalyticsHubScreenState

## lib\features\analytics\views\analytics_hub_view.dart
- [class] AnalyticsHubView
- [class] _AnalyticsHubViewState

## lib\features\analytics\views\pattern_comparison_view.dart
- [class] PatternComparisonView

## lib\features\analytics\views\series_pattern_carousel_view.dart
- [class] SeriesPatternCarouselView
- [class] _SeriesPatternContent
- [class] _PaceProgressionChart

## lib\features\analytics\views\series_pattern_detail_view.dart
- [class] SeriesPatternDetailView
- [class] _PaceProgressionChart

## lib\features\analytics\views\tabs\distribution_tab.dart
- [class] DistributionTab
- [class] _TagDistributionContent
- [class] _TagDistributionContentState

## lib\features\analytics\views\tabs\overview_tab.dart
- [class] OverviewTab
- [class] _WeeklyVolumeChart
- [class] _PaceEvolutionChart
- [class] _TagDistributionContent
- [class] _TagDistributionContentState

## lib\features\analytics\views\tabs\patterns_tab.dart
- [class] PatternsTab
- [class] SeriesPatternCard
- [class] WorkoutPatternCard

## lib\features\analytics\views\tabs\trends_tab.dart
- [class] TrendsTab
- [class] _WeeklyVolumeChart
- [class] _PaceEvolutionChart

## lib\features\analytics\views\workout_pattern_carousel_view.dart
- [class] WorkoutPatternCarouselView
- [class] _WorkoutPatternCarouselViewState
- [class] _ComparisonSelectorSheet
- [class] _ComparisonSelectorSheetState
- [class] _WorkoutPatternContent
- [class] _PerformanceChart

## lib\features\analytics\views\workout_pattern_detail_view.dart
- [class] WorkoutPatternDetailView
- [class] _PerformanceChart

## lib\features\analytics\widgets\analytics_range_selector.dart
- [class] AnalyticsRangeSelector

## lib\features\analytics\widgets\coach_insight_widget.dart
- [class] CoachInsightWidget

## lib\features\analytics\widgets\pattern_carousel.dart
- [class] PatternCarousel
- [class] _PatternCarouselState

## lib\features\auth\data\auth_remote.dart
- [class] AuthRemote

## lib\features\auth\data\auth_repository.dart
- [class] AuthRepository

## lib\features\auth\viewmodels\auth_controller.dart
- [class] AuthController

## lib\features\auth\views\auth_page.dart
- [class] AuthPage
- [class] _AuthPageState

## lib\features\avatar\data\background_shape.dart
- [enum] BackgroundShape

## lib\features\avatar\viewmodels\avatar_maker_controller.dart
- [class] AvatarMakerController

## lib\features\avatar\views\avatar_maker_screen.dart
- [class] AvatarMakerScreen
- [class] _AvatarMakerScreenState

## lib\features\avatar\widgets\avatar_color_picker.dart
- [class] AppColorTheme

## lib\features\avatar\widgets\avatar_text_styles.dart
- [class] AppTextStyle

## lib\features\groups\data\helpers\challenge_helpers.dart
- [class] ChallengeFilters
- [class] ChallengeGoal

## lib\features\groups\data\helpers\challenge_ranking_helper.dart
- [class] ChallengeRankingHelper
- [extension] GoalKindExtension

## lib\features\groups\data\helpers\period_helper.dart
- [class] PeriodHelper

## lib\features\groups\data\models\challenge_models.dart
- [class] ChallengeTemplate
- [class] Challenge
- [class] ChallengeParticipant
- [class] GroupPrefs

## lib\features\groups\data\models\enums.dart
- [enum] GroupType
- [enum] MemberStatus
- [enum] ChallengePeriodicity
- [enum] ChallengeMetric
- [enum] ChallengeAggregation
- [enum] ChallengeOrigin
- [enum] ChallengeStatus
- [enum] TieBreakerType
- [enum] MedalType
- [enum] BadgeType
- [enum] GoalKind
- [enum] GroupNotificationType

## lib\features\groups\data\models\group_models.dart
- [class] Group
- [class] GroupMember
- [class] Invite

## lib\features\groups\data\models\group_stats_model.dart
- [class] GroupModel
- [class] GroupMemberStats

## lib\features\groups\data\models\result_notification_model.dart
- [class] GroupResultNotification

## lib\features\groups\data\models\rewards_models.dart
- [class] GroupMedals
- [class] MedalHistoryEntry
- [class] GroupBadges
- [class] BadgeHistoryEntry

## lib\features\groups\data\repositories\challenges_repository.dart
- [class] ChallengesRepository

## lib\features\groups\data\repositories\groups_repository.dart
- [class] GroupsRepository

## lib\features\groups\data\repositories\group_detail_repository.dart
- [class] GroupDetailRepository

## lib\features\groups\data\repositories\group_prefs_repository.dart
- [class] GroupPrefsRepository

## lib\features\groups\data\repositories\invites_repository.dart
- [class] InvitesRepository

## lib\features\groups\data\repositories\rewards_repository.dart
- [class] RewardsRepository

## lib\features\groups\data\repositories\templates_repository.dart
- [class] TemplatesRepository

## lib\features\groups\data\repositories\user_groups_repository.dart
- [class] UserGroupMembership
- [class] UserGroupsRepository

## lib\features\groups\data\services\auto_join_service.dart
- [class] AutoJoinService

## lib\features\groups\data\services\challenge_calculator.dart
- [class] ChallengeCalculator

## lib\features\groups\data\services\challenge_finalize_service.dart
- [class] ChallengeFinalizeService

## lib\features\groups\data\services\ensure_auto_challenges_service.dart
- [class] EnsureAutoChallengesService

## lib\features\groups\data\services\gamification_service.dart
- [class] Achievement
- [class] GamificationService

## lib\features\groups\data\services\training_challenge_sync_service.dart
- [class] TrainingChallengeSyncService

## lib\features\groups\data\services\user_lookup_service.dart
- [class] UserLookupService

## lib\features\groups\viewmodels\challenge_detail_controller.dart
- [class] ChallengeDetailController

## lib\features\groups\viewmodels\group_challenges_controller.dart
- [class] GroupChallengesController

## lib\features\groups\viewmodels\group_rewards_controller.dart
- [class] GroupRewardsController

## lib\features\groups\views\challenge_detail_screen.dart
- [class] ChallengeDetailScreen
- [class] _ChallengeDetailScreenState
- [class] _AnimatedBackButton
- [class] _AnimatedBackButtonState
- [extension] GoalKindToMetric

## lib\features\groups\views\groups_list_screen.dart
- [class] GroupsListScreen
- [class] _GroupsListScreenState
- [class] _CreateGroupModal
- [class] _PremiumGroupCard
- [class] _PremiumGroupCardState
- [class] _InvitationCard
- [class] _InvitationCardState
- [class] _GlassBadge
- [class] _StaggeredGroupItem
- [class] _StaggeredGroupItemState
- [class] _PremiumFloatingActionButton
- [class] _PremiumFloatingActionButtonState

## lib\features\groups\views\group_rewards_screen.dart
- [class] GroupRewardsScreen
- [class] _GroupRewardsScreenState
- [class] _PremiumMedalCard
- [class] _PremiumBadgeCard
- [class] _MedalCounter
- [class] _StaggeredItem
- [class] _StaggeredItemState
- [class] _AnimatedBackButton
- [class] _AnimatedBackButtonState

## lib\features\groups\views\group_screen.dart
- [class] GroupScreen
- [class] _GroupScreenState
- [class] _AnimatedBackButton
- [class] _AnimatedBackButtonState
- [class] _PremiumChallengeCard
- [class] _PremiumChallengeCardState
- [class] _PremiumMemberCard
- [class] _StaggeredChallengeItem
- [class] _StaggeredChallengeItemState
- [class] _StaggeredMemberItem
- [class] _StaggeredMemberItemState
- [class] _PremiumFloatingActionButton
- [class] _PremiumFloatingActionButtonState

## lib\features\groups\views\participant_profile_screen.dart
- [class] ParticipantProfileScreen
- [class] _ParticipantProfileScreenState
- [class] _StatItem
- [class] _AchievementCard

## lib\features\groups\views\widgets\challenge_result_dialog.dart
- [class] ChallengeResultDialog
- [class] _ChallengeResultDialogState

## lib\features\groups\views\widgets\create_challenge_modal.dart
- [class] CreateChallengeModal
- [class] _CreateChallengeModalState

## lib\features\history\viewmodels\history_analytics_view_model.dart
- [class] HistoryAnalyticsViewModel

## lib\features\history\viewmodels\history_controller.dart
- [enum] TrainingFilter
- [class] HistoryController

## lib\features\history\views\history_screen.dart
- [class] HistoryScreen
- [class] _HistoryScreenState

## lib\features\history\widgets\filter_badge_button.dart
- [class] FilterBadgeButton

## lib\features\history\widgets\history_bottom_bar.dart
- [class] HistoryBottomBar

## lib\features\history\widgets\history_calendar_widget.dart
- [class] HistoryCalendarWidget
- [class] _HistoryCalendarWidgetState

## lib\features\history\widgets\history_filter_sheet.dart
- [class] HistoryFilterSheet
- [class] _HistoryFilterSheetState

## lib\features\history\widgets\history_search_bar.dart
- [class] HistorySearchBar
- [class] _HistorySearchBarState

## lib\features\history\widgets\premium_training_card.dart
- [class] PremiumTrainingCard
- [class] _PremiumTrainingCardState

## lib\features\home\data\home_estadistica_repository.dart
- [enum] HomeMetric
- [enum] TimeRange
- [class] DailyMetric
- [class] HomeEstadisticaRepository

## lib\features\home\viewmodels\home_config_controller.dart
- [class] HomeConfigController

## lib\features\home\viewmodels\home_estadistica_controller.dart
- [class] HomeEstadisticaController

## lib\features\home\views\edit_home_view.dart
- [class] EditHomeView
- [class] _EditHomeViewState

## lib\features\home\views\home_view.dart
- [class] HomeView
- [class] _HomeViewState
- [enum] TimeRange
- [class] _GroupHighlightCard

## lib\features\home\widgets\configurable_widget_renderer.dart
- [class] ConfigurableWidgetRenderer

## lib\features\home\widgets\history_carousel.dart
- [class] HistoryCarousel
- [class] _HistoryCarouselState

## lib\features\home\widgets\home_flagship_chart.dart
- [enum] ChartFlagshipRange
- [enum] ChartFlagshipMetric
- [class] HomeFlagshipChart
- [class] _HomeFlagshipChartState
- [class] _ChartGroup

## lib\features\home\widgets\legacy_bar_chart.dart
- [enum] HomeMetric
- [enum] TimeRange
- [class] DailyMetric
- [class] LegacyBarChart
- [class] _LegacyBarChartState
- [class] _BarChartPainter

## lib\features\home\widgets\stats_carousel.dart
- [class] StatsCarousel
- [class] _StatsCarouselState

## lib\features\profile\views\avatar_editor_wraper_view.dart
- [class] AvatarEditorWrapperView
- [class] _AvatarEditorWrapperViewState

## lib\features\profile\views\edit_profile_picture_view.dart
- [class] EditProfilePictureView

## lib\features\profile\views\profile_menu_screen.dart
- [class] ProfileMenuView
- [class] _ProfileMenuViewState

## lib\features\training\data\entrenamiento.dart
- [class] Entrenamiento

## lib\features\training\data\entrenamiento_utils.dart
- [class] EntrenamientoUtils
- [class] WeekStats

## lib\features\training\data\serie.dart
- [class] Serie

## lib\features\training\data\tag_manager.dart
- [class] TagManager

## lib\features\training\data\tag_model.dart
- [class] TrainingTag
- [class] TagColors

## lib\features\training\data\training_repository.dart
- [class] TrainingRepository

## lib\features\training\viewmodels\training_viewmodel.dart
- [class] TrainingViewModel

## lib\features\training\views\training_session_view.dart
- [class] TrainingSessionView
- [class] _TrainingSessionViewState

## lib\features\training\views\training_start_view.dart
- [enum] AlarmMode
- [class] TrainingStartView
- [class] _TrainingStartViewState

## lib\features\training\widgets\create_tag_dialog.dart
- [class] CreateTagDialog
- [class] _CreateTagDialogState

## lib\features\training\widgets\tag_chip.dart
- [class] TagChip

## lib\features\training\widgets\tag_selector_sheet.dart
- [class] TagSelectorSheet
- [class] _TagSelectorSheetState

## lib\firebase_options.dart
- [class] DefaultFirebaseOptions

## lib\main.dart
- [class] MyApp

