local Screen = require "widgets/screen"
local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"
local Button = require "widgets/button"
local ImageButton = require "widgets/imagebutton"

local DevelopmentScreen = Class(Screen, function(self)
    Screen._ctor(self, "DevelopmentScreen")

    self.root = self:AddChild(Widget("root"))
    self.root:SetVAnchor(ANCHOR_MIDDLE)
    self.root:SetHAnchor(ANCHOR_MIDDLE)
    self.root:SetScaleMode(SCALEMODE_PROPORTIONAL)

    self.bg = self.root:AddChild(Image("images/global.xml", "square.tex"))
    self.bg:SetVRegPoint(ANCHOR_MIDDLE)
    self.bg:SetHRegPoint(ANCHOR_MIDDLE)
    self.bg:SetVAnchor(ANCHOR_MIDDLE)
    self.bg:SetHAnchor(ANCHOR_MIDDLE)
    self.bg:SetScaleMode(SCALEMODE_FILLSCREEN)
    self.bg:SetTint(0, 0, 0, .75)

    self.title = self.root:AddChild(Text(TITLEFONT, 30, "Development Menu"))
    self.title:SetPosition(0, RESOLUTION_Y / 2 - self.title:GetSize())
end)

return DevelopmentScreen
