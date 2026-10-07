Scriptname AshmanTeleportScript extends ActiveMagicEffect

; FAST TRAVEL TO AND FROM INTERIORS
;
; DESIGN
; Skyrim's predefined Message forms supply individual button menus. This
; script connects those menus into a hierarchy without replacing the UI.
; Vanilla Skyrim Papyrus has no native arrays of arrays, so destinations
; are stored in a flat array representing destinations[category][slot].
;
; The data structure and navigation solve separate problems:
;   - Flat-array indexing organizes destinations and their menu pages.
;   - A loop changes navigation state without recursive menu calls.
;
; CREATION KIT CONTRACT
; Message forms and destination markers live in the plugin, not this file.
; Keep their property bindings and button order aligned with these tables.
;
; Main page 0: button 0 = Cancel, 1-5 = categories 0-4, 6 = More.
; Main page 1: button 0 = Back,   1-5 = categories 5-9.
; Category page 0: button 0 = Back, 1-5 = slots 0-4, 6 = More.
; Category page 1: button 0 = Back, 1-5 = slots 5-9.
; Short menus may omit trailing destinations and the More button. Do not
; reorder destination buttons or put a navigation button in their positions.
;
; Category  Name                       Destination indices  Menu indices
; 0         Homes                      0-9                  0, 10
; 1         Quest headquarters         10-19                1, 11
; 2         General merchants          20-29                2, 12
; 3         Smiths                     30-39                3, 13
; 4         Jarls and mages            40-49                4, 14
; 5         Apothecaries               50-59                5, 15
; 6         Inns                       60-69                6, 16
; 7         Blackreach and other areas 70-79                7, 17
; 8         Miscellaneous              80-89                8, 18
; 9         Stables                    90-99                9, 19
;
; Existing property names are retained for Creation Kit bindings. Their
; numeric prefixes are historical identifiers, not array indices. Only
; properties referenced by the active menus and destination table remain.
;
; ADDING OR CHANGING A DESTINATION
; 1. Declare an ObjectReference property and bind it to a marker in the CK.
; 2. Assign it to the correct category/slot in InitializeData().
; 3. Update the corresponding Message form's button label and position.
; 4. Test the first page, More, Back, and the destination in Skyrim.
; Adding categories or pages also requires updating the layout and menus.

; Menu forms, configured in the Creation Kit.
Message Property AshmanTeleportMainMenu Auto
Message Property AshmanTeleportMainMoreMenu Auto
Message Property HomesMenu Auto
Message Property QuestHQMenu Auto
Message Property GeneralMenu Auto
Message Property SmithMenu Auto
Message Property ApothecaryMenu Auto
Message Property JarlMenu Auto
Message Property InnMenu Auto
Message Property BlackreachMenu Auto
Message Property MiscMenu Auto
Message Property StablesMenu Auto
Message Property HomesMoreMenu Auto
Message Property QuestHQMoreMenu Auto
Message Property GeneralMoreMenu Auto
Message Property SmithMoreMenu Auto
Message Property ApothecaryMoreMenu Auto
Message Property JarlMoreMenu Auto
Message Property InnMoreMenu Auto
Message Property BlackreachMoreMenu Auto
Message Property MiscMoreMenu Auto
Message Property StablesMoreMenu Auto

; Destination markers, configured in the Creation Kit.
ObjectReference Property Loc01Breezehome Auto
ObjectReference Property Loc02Honeyside Auto
ObjectReference Property Loc03Vlindrell Auto
ObjectReference Property Loc04Hjerim Auto
ObjectReference Property Loc05Proudspire Auto
ObjectReference Property Loc06LakeView Auto
ObjectReference Property Loc07Heljarchen Auto
ObjectReference Property Loc00Severin Auto
ObjectReference Property Loc09Archmage Auto
ObjectReference Property Loc09Attainment Auto
ObjectReference Property LocQJorrvaskr Auto
ObjectReference Property LocQJorrvaskrLQ Auto
ObjectReference Property LocQCWArcaneum Auto
ObjectReference Property LocQCWCountenance Auto
ObjectReference Property LocQRaggedFlagon Auto
ObjectReference Property LocQRaggedCistern Auto
ObjectReference Property LocQSanctuary Auto
ObjectReference Property LocQDSSanctuary Auto
ObjectReference Property LocQBardsCollege Auto
ObjectReference Property LocQCastleDour Auto
ObjectReference Property Loc10Belethor Auto
ObjectReference Property Loc11Bersi Auto
ObjectReference Property Loc12Brand Auto
ObjectReference Property Loc13Falkreath Auto
ObjectReference Property Loc14Markarth Auto
ObjectReference Property Loc15Tonilia Auto
ObjectReference Property Loc16Niranye Auto
ObjectReference Property Loc17Solitude Auto
ObjectReference Property Loc18Windhelm Auto
ObjectReference Property Loc19Radient Auto
ObjectReference Property Loc20Warmaidens Auto
ObjectReference Property Loc21WarmaidensOut Auto
ObjectReference Property Loc22Windhelm Auto
ObjectReference Property Loc23Riverwood Auto
ObjectReference Property Loc24Markarth Auto
ObjectReference Property Loc25Solitude Auto
ObjectReference Property Loc26Glover Auto
ObjectReference Property Loc27Falkreath Auto
ObjectReference Property Loc28Dawnstar Auto
ObjectReference Property Loc29Dawnguard Auto
ObjectReference Property Loc30Arcadia Auto
ObjectReference Property Loc31Windhelm Auto
ObjectReference Property Loc32Falkreath Auto
ObjectReference Property Loc33Solitude Auto
ObjectReference Property Loc34Markarth Auto
ObjectReference Property Loc35Riften Auto
ObjectReference Property Loc36Dawnstar Auto
ObjectReference Property Loc37Morthal Auto
ObjectReference Property Loc38TelMithryn Auto
ObjectReference Property Loc50SolitudeJarl Auto
ObjectReference Property LocJMWhiterun Auto
ObjectReference Property LocJMWinterhold Auto
ObjectReference Property LocJMDawnstar Auto
ObjectReference Property LocJMFalkreath Auto
ObjectReference Property LocJMMarkarth Auto
ObjectReference Property LocJMMorthal Auto
ObjectReference Property LocJMRiften Auto
ObjectReference Property LocJMWindhelm Auto
ObjectReference Property LocJMTelMithryn Auto
ObjectReference Property Loc60WinterholdInn Auto
ObjectReference Property Loc61SolitudeInn Auto
ObjectReference Property LocInnsWhiterun Auto
ObjectReference Property LocInnsRiverwood Auto
ObjectReference Property LocInnsRiften Auto
ObjectReference Property LocInnsMarkarth Auto
ObjectReference Property LocInnsMorthal Auto
ObjectReference Property LocInnsFalkreath Auto
ObjectReference Property LocInnsWindhelm Auto
ObjectReference Property LocInnsDawnstar Auto
ObjectReference Property LocBRAlftandLift Auto
ObjectReference Property LocBRMzinchaleftLIft Auto
ObjectReference Property LocBRRaldbtharLift Auto
ObjectReference Property LocBRTowerMzark Auto
ObjectReference Property LocFVParagon Auto
ObjectReference Property LocFVIllumination Auto
ObjectReference Property LocSCSoulCairnStart Auto
ObjectReference Property LocSCSoulCairnMiddle Auto
ObjectReference Property Loc80SummitApocrypha Auto
ObjectReference Property Loc81Blackreach Auto
ObjectReference Property Loc82NchuandArmory Auto
ObjectReference Property Loc90WhiterunStable Auto
ObjectReference Property Loc91MarkarthStable Auto

; Layout values are named once so indexing formulas express their meaning.
; These are private script variables, treated as constants by this script.
Int CategoryCount = 10
Int EntriesPerCategory = 10
Int EntriesPerPage = 5
Int BackButton = 0
Int MoreButton = 6
Int MainMenuCategory = -1

; Shared data belongs to this script instance; functions access it directly.
Message[] CategoryMenu
ObjectReference[] LocationMasterList

Event OnEffectStart(Actor akTarget, Actor akCaster)
    ; Build the lookup tables before opening any menu. This avoids depending
    ; on a separate OnInit event having finished before the effect starts.
    InitializeData()
    RunMenuNavigation()
EndEvent

Function InitializeData()
    ; Vanilla Papyrus requires literal sizes in New array expressions.
    ; 20 = two pages * ten categories; 100 = ten slots * ten categories.
    ; Rebuilding also clears unused slots to None on each activation.
    CategoryMenu = New Message[20]
    LocationMasterList = New ObjectReference[100]

    ; First category pages: menuIndex = categoryIndex.
    CategoryMenu[0] = HomesMenu
    CategoryMenu[1] = QuestHQMenu
    CategoryMenu[2] = GeneralMenu
    CategoryMenu[3] = SmithMenu
    CategoryMenu[4] = JarlMenu
    CategoryMenu[5] = ApothecaryMenu
    CategoryMenu[6] = InnMenu
    CategoryMenu[7] = BlackreachMenu
    CategoryMenu[8] = MiscMenu
    CategoryMenu[9] = StablesMenu

    ; Second category pages: menuIndex = categoryIndex + CategoryCount.
    CategoryMenu[10] = HomesMoreMenu
    CategoryMenu[11] = QuestHQMoreMenu
    CategoryMenu[12] = GeneralMoreMenu
    CategoryMenu[13] = SmithMoreMenu
    CategoryMenu[14] = JarlMoreMenu
    CategoryMenu[15] = ApothecaryMoreMenu
    CategoryMenu[16] = InnMoreMenu
    CategoryMenu[17] = BlackreachMoreMenu
    CategoryMenu[18] = MiscMoreMenu
    CategoryMenu[19] = StablesMoreMenu

    ; Category 0: Homes; slots 0-9.
    LocationMasterList[0] = Loc01Breezehome
    LocationMasterList[1] = Loc09Attainment
    LocationMasterList[2] = Loc09Archmage
    LocationMasterList[3] = Loc02Honeyside
    LocationMasterList[4] = Loc00Severin
    LocationMasterList[5] = Loc03Vlindrell
    LocationMasterList[6] = Loc04Hjerim
    LocationMasterList[7] = Loc05Proudspire
    LocationMasterList[8] = Loc06LakeView
    LocationMasterList[9] = Loc07Heljarchen


    ; Category 1: Quest headquarters; slots 10-19.
    LocationMasterList[10] = LocQJorrvaskr
    LocationMasterList[11] = LocQJorrvaskrLQ
    LocationMasterList[12] = LocQCWArcaneum
    LocationMasterList[13] = LocQCWCountenance
    LocationMasterList[14] = LocQRaggedFlagon
    LocationMasterList[15] = LocQRaggedCistern
    LocationMasterList[16] = LocQSanctuary
    LocationMasterList[17] = LocQDSSanctuary
    LocationMasterList[18] = LocQBardsCollege
    LocationMasterList[19] = LocQCastleDour


    ; Category 2: General merchants; slots 20-29.
    LocationMasterList[20] = Loc10Belethor
    LocationMasterList[21] = Loc11Bersi
    LocationMasterList[22] = Loc12Brand
    LocationMasterList[23] = Loc13Falkreath
    LocationMasterList[24] = Loc14Markarth
    LocationMasterList[25] = Loc15Tonilia
    LocationMasterList[26] = Loc16Niranye
    LocationMasterList[27] = Loc17Solitude
    LocationMasterList[28] = Loc18Windhelm
    LocationMasterList[29] = Loc19Radient


    ; Category 3: Smiths; slots 30-39.
    LocationMasterList[30] = Loc20Warmaidens
    LocationMasterList[31] = Loc21WarmaidensOut
    LocationMasterList[32] = Loc23Riverwood
    LocationMasterList[33] = Loc29Dawnguard
    LocationMasterList[34] = Loc26Glover
    LocationMasterList[35] = Loc25Solitude
    LocationMasterList[36] = Loc24Markarth
    LocationMasterList[37] = Loc27Falkreath
    LocationMasterList[38] = Loc22Windhelm
    LocationMasterList[39] = Loc28Dawnstar


    ; Category 4: Jarls and mages; slots 40-49.
    LocationMasterList[40] = LocJMWhiterun
    LocationMasterList[41] = Loc50SolitudeJarl
    LocationMasterList[42] = LocJMWindhelm
    LocationMasterList[43] = LocJMFalkreath
    LocationMasterList[44] = LocJMRiften
    LocationMasterList[45] = LocJMMorthal
    LocationMasterList[46] = LocJMMarkarth
    LocationMasterList[47] = LocJMWinterhold
    LocationMasterList[48] = LocJMDawnstar
    LocationMasterList[49] = LocJMTelMithryn


    ; Category 5: Apothecaries; slots 50-59.
    LocationMasterList[50] = Loc30Arcadia
    LocationMasterList[51] = Loc31Windhelm
    LocationMasterList[52] = Loc32Falkreath
    LocationMasterList[53] = Loc33Solitude
    LocationMasterList[54] = Loc34Markarth
    LocationMasterList[55] = Loc35Riften
    LocationMasterList[56] = Loc36Dawnstar
    LocationMasterList[57] = Loc37Morthal
    LocationMasterList[58] = Loc38TelMithryn
    ; Unused slots stay None: 59.


    ; Category 6: Inns; slots 60-69.
    LocationMasterList[60] = LocInnsWhiterun
    LocationMasterList[61] = LocInnsRiverwood
    LocationMasterList[62] = LocInnsRiften
    LocationMasterList[63] = Loc60WinterholdInn
    LocationMasterList[64] = Loc61SolitudeInn
    LocationMasterList[65] = LocInnsWindhelm
    LocationMasterList[66] = LocInnsFalkreath
    LocationMasterList[67] = LocInnsMorthal
    LocationMasterList[68] = LocInnsMarkarth
    LocationMasterList[69] = LocInnsDawnstar


    ; Category 7: Blackreach and other areas; slots 70-79.
    ; REVIEW: slot 76 and slot 80 both use Loc80SummitApocrypha?
    ; confirm both Message labels in CK.
    LocationMasterList[70] = LocBRAlftandLift
    LocationMasterList[71] = LocBRMzinchaleftLIft
    LocationMasterList[72] = LocBRRaldbtharLift
    LocationMasterList[73] = LocBRTowerMzark
    LocationMasterList[74] = LocFVParagon
    LocationMasterList[75] = LocFVIllumination
    LocationMasterList[76] = Loc80SummitApocrypha
    LocationMasterList[77] = LocSCSoulCairnStart
    LocationMasterList[78] = LocSCSoulCairnMiddle
    ; Unused slots stay None: 79.


    ; Category 8: Miscellaneous; slots 80-89.
    LocationMasterList[80] = Loc80SummitApocrypha
    LocationMasterList[81] = Loc81Blackreach
    LocationMasterList[82] = Loc82NchuandArmory
    ; Unused slots stay None: 83, 84, 85, 86, 87, 88, 89.


    ; Category 9: Stables; slots 90-99.
    LocationMasterList[90] = Loc90WhiterunStable
    LocationMasterList[91] = Loc91MarkarthStable
    ; Unused slots stay None: 92, 93, 94, 95, 96, 97, 98, 99.
EndFunction

Function RunMenuNavigation()
    ; categoryIndex == MainMenuCategory means a main category-selection menu.
    ; Otherwise it identifies a destination category, independent of page.
    ; These locals reset with every activation; no correction state leaks
    ; into a later selection or another call to this function.
    Int categoryIndex = MainMenuCategory
    Int mainPage = 0
    Int categoryPage = 0
    Int buttonIndex
    Int menuIndex
    Int destinationIndex
    Message currentMenu

    ; Show() waits for a selection. The loop does not poll or recursively
    ; reopen itself: each iteration shows exactly one configured menu.
    ; Cancel, a completed travel sequence, or a menu error returns directly.
    While True
        If categoryIndex == MainMenuCategory
            If mainPage == 0
                currentMenu = AshmanTeleportMainMenu
            Else
                currentMenu = AshmanTeleportMainMoreMenu
            EndIf

            buttonIndex = ShowConfiguredMenu(currentMenu)
            If buttonIndex < 0
                Return
            EndIf

            If buttonIndex == BackButton
                If mainPage == 0
                    Return
                Else
                    mainPage = 0
                EndIf
            ElseIf buttonIndex == MoreButton && mainPage == 0
                mainPage = 1
            ElseIf buttonIndex >= 1 && buttonIndex <= EntriesPerPage
                categoryIndex = (mainPage * EntriesPerPage) + buttonIndex - 1
                categoryPage = 0
            Else
                ReportConfigurationError("Unexpected main-menu button: " + buttonIndex)
                Return
            EndIf
        Else
            menuIndex = GetCategoryMenuIndex(categoryIndex, categoryPage)
            If menuIndex < 0
                ReportConfigurationError("Invalid category or page.")
                Return
            EndIf

            currentMenu = CategoryMenu[menuIndex]
            buttonIndex = ShowConfiguredMenu(currentMenu)
            If buttonIndex < 0
                Return
            EndIf

            If buttonIndex == BackButton
                If categoryPage == 1
                    ; Back from More returns to this category's first page.
                    categoryPage = 0
                Else
                    ; Back from a category
                    ; returns to the FIRST main page, even for categories 5-9.
                    categoryIndex = MainMenuCategory
                    mainPage = 0
                EndIf
            ElseIf buttonIndex == MoreButton && categoryPage == 0
                categoryPage = 1
            ElseIf buttonIndex >= 1 && buttonIndex <= EntriesPerPage
                destinationIndex = GetLocationIndex(categoryIndex, buttonIndex, categoryPage)
                If TeleportPlayer(destinationIndex)
                    Return
                EndIf
                ; Missing destination: report it and redisplay the current
                ; menu so the player can choose another entry or go Back.
            Else
                ReportConfigurationError("Unexpected category-menu button: " + buttonIndex)
                Return
            EndIf
        EndIf
    EndWhile
EndFunction

Int Function ShowConfiguredMenu(Message menuToShow)
    If menuToShow == None
        ReportConfigurationError("A required Message property is unassigned.")
        Return -1
    EndIf

    Int buttonIndex = menuToShow.Show()
    If buttonIndex < 0
        ; Show() returns -1 for a non-message-box form or an error. Treat
        ; that as an exit, never as a category or destination array index.
        ReportConfigurationError("Message.Show returned no valid button.")
    EndIf
    Return buttonIndex
EndFunction

Int Function GetCategoryMenuIndex(Int categoryIndex, Int pageIndex)
    If categoryIndex < 0 || categoryIndex >= CategoryCount
        Return -1
    EndIf
    If pageIndex < 0 || pageIndex > 1
        Return -1
    EndIf
    If CategoryMenu == None
        Return -1
    EndIf

    Int menuIndex = categoryIndex + (pageIndex * CategoryCount)
    If menuIndex >= CategoryMenu.Length
        Return -1
    EndIf
    Return menuIndex
EndFunction

Int Function GetLocationIndex(Int categoryIndex, Int buttonIndex, Int pageIndex)
    ; Call only for destination buttons. Back (0) and More (6) are excluded.
    If categoryIndex < 0 || categoryIndex >= CategoryCount
        Return -1
    EndIf
    If buttonIndex < 1 || buttonIndex > EntriesPerPage
        Return -1
    EndIf
    If pageIndex < 0 || pageIndex > 1
        Return -1
    EndIf

    ; Flattened two-dimensional storage:
    ;   slot = zero-based button position + page offset
    ;   index = category * entries per category + slot
    ; Example: Smiths (3), second destination (2), More page (1):
    ;   slot = (2 - 1) + (1 * 5) = 6
    ;   index = (3 * 10) + 6 = 36 -> Loc24Markarth
    Int slotIndex = (buttonIndex - 1) + (pageIndex * EntriesPerPage)
    Return (categoryIndex * EntriesPerCategory) + slotIndex
EndFunction

Bool Function TeleportPlayer(Int destinationIndex)
    ; Validate before indexing or invoking any movement functions.
    If LocationMasterList == None
        ReportConfigurationError("The destination table is not initialized.")
        Return False
    EndIf
    If destinationIndex < 0 || destinationIndex >= LocationMasterList.Length
        ReportConfigurationError("Destination index is out of range: " + destinationIndex)
        Return False
    EndIf

    ObjectReference destination = LocationMasterList[destinationIndex]
    If destination == None
        ReportConfigurationError("No destination is assigned at slot " + destinationIndex)
        Return False
    EndIf

    Actor player = Game.GetPlayer()
    If player == None
        ReportConfigurationError("The player reference is unavailable.")
        Return False
    EndIf

    ; MoveTo relocates the player.
    ; EnableFastTravel and FastTravel then request engine fast travel.
    ; This source does not establish why both movement calls were required.
    ; Verify their combined behavior in-game before simplifying the sequence,
    ; particularly for interiors, worldspace changes, followers, and time.
    Utility.Wait(1.5)
    Game.FadeOutGame(False, True, 1.0, 1.0)
    player.MoveTo(destination)
    Game.EnableFastTravel()
    Game.FastTravel(destination)

    ; True means the calls were issued, not that arrival was verified:
    Return True
EndFunction

Function ReportConfigurationError(String details)
    ; Keep diagnostics in the Papyrus log and give the player a short notice.
    Debug.Trace("[AshmanTeleportScript] " + details, 2)
    Debug.Notification("Fast Travel mod: " + details)
EndFunction
