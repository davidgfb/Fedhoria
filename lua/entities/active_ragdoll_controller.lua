ddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
 
ENT.AutomaticFrameAdvance = true

function ENT:SetupDataTables()
	self:NetworkVar("Entity", 0, "Target")
end

function ENT:SetModule(mod)
	self.Module = mod
end

function ENT:SetInitParams(...)
	self.InitParams = {...}
end

local FORCE_SCALE = 3

local math_atan2 	= math.atan2
local math_min 		= math.min
local math_max 		= math.max
local math_abs 		= math.abs

local phys_settings = 
{
	["ValveBiped.Bip01_Pelvis"] = {mass = 12.741364, inertia = Vector(0.80, 0.97, 0.96)},

	["ValveBiped.Bip01_Spine2"] = {mass = 24.297474, inertia = Vector(2.15, 3.33, 3.12)},

	["ValveBiped.Bip01_R_UpperArm"] = {mass = 3.529606, inertia = Vector(0.06, 0.28, 0.28)},

	["ValveBiped.Bip01_L_UpperArm"] = {mass = 3.466939, inertia = Vector(0.06, 0.27, 0.27)},

	["ValveBiped.Bip01_L_Forearm"] = {mass = 1.801132, inertia = Vector(0.02, 0.10, 0.10)},

	["ValveBiped.Bip01_L_Hand"] = {mass = 1.075074, inertia = Vector(0.02, 0.02, 0.02)},

	["ValveBiped.Bip01_R_Forearm"] = {mass = 1.781718, inertia = Vector(0.02, 0.10, 0.10)},

	["ValveBiped.Bip01_R_Hand"] = {mass = 1.018670, inertia = Vector(0.02, 0.02, 0.02)},

	["ValveBiped.Bip01_R_Thigh"] = {mass = 10.187500, inertia = Vector(0.35, 1.74, 1.76)},

	["ValveBiped.Bip01_R_Calf"] = {mass = 4.996145, inertia = Vector(0.10, 0.63, 0.64)},

	["ValveBiped.Bip01_Head1"] = {mass = 5.163157, inertia = Vector(0.19, 0.21, 0.27)},

	["ValveBiped.Bip01_L_Thigh"] = {mass = 10.188610, inertia = Vector(0.35, 1.74, 1.76)},

	["ValveBiped.Bip01_L_Calf"] = {mass = 4.995875, inertia = Vector(0.10, 0.63, 0.64)},

	["ValveBiped.Bip01_L_Foot"] = {mass = 2.378366, inertia = Vector(0.05, 0.13, 0.13)},

	["ValveBiped.Bip01_R_Foot"] = {mass = 2.378366, inertia = Vector(0.05, 0.13, 0.13)}
}

function ENT:PhysAlignAngles(phys, ang) 
	local avel = Vector(0, 0, 0)
	
	local ang1 = phys:GetAngles()
		
	local forward1 = ang1:Forward()
	local forward2 = ang:Forward()
	local fd = forward1:Dot(forward2)
	
	local right1 = ang1:Right()
	local right2 = ang:Right()
	local rd = right1:Dot(right2)
	
	local up1 = ang1:Up()
	local up2 = ang:Up()
	local ud = up1:Dot(up2)
	
	local pitchvel = math.asin(forward1:Dot(up2)) * 180 / math.pi
	local yawvel = math.asin(forward1:Dot(right2)) * 180 / math.pi
	local rollvel = math.asin(right1:Dot(up2)) * 180 / math.pi
		
	avel.y = avel.y + pitchvel
	avel.z = avel.z + yawvel
	avel.x = avel.x + rollvel
		
	return avel
end

function ENT:SetMaxAngVel(val)
	self.max_ang_vel = val
	self.max_ang_vel_sqr = val * val
end

function ENT:SetBoneList(list)
	self.bone_list = list
end

function ENT:Initialize()
	if !self.Module then return end

	self:SetModel(self.Module.Model)

	for key, value in pairs(self.Module) do
		if !self[key] then
			self[key] = value
		end
	end

	self:StartMotionController()

	local target = self:GetTarget()

	if !target._FixedSettings then
		target._FixedSettings = true
		for bone_name, info in pairs(phys_settings) do
		 	local bone = target:LookupBone(bone_name)
		 	if bone then
		 		local phys_bone = target:TranslateBoneToPhysBone(bone)
		 		local phys = target:GetPhysicsObjectNum(phys_bone)
		 		if IsValid(phys) then
			 		phys:SetInertia(info.inertia)
			 		phys:SetMass(info.mass)
			 	end
			end
		end
	end

	self.bone_translate = {}
	self.bone_parent = {}

	local is_match = false

	for _, bone_name in pairs(self.Module.BoneList) do
		local bone = target:LookupBone(bone_name)
		if bone then
			is_match = true				
			local phys_bone = target:TranslateBoneToPhysBone(bone)
			local phys = target:GetPhysicsObjectNum(phys_bone)
			if IsValid(phys) then
				bone = target:TranslatePhysBoneToBone(phys_bone)

				self.root_bone = self.root_bone or bone
				self.root_phys_bone = self.root_phys_bone or phys_bone

				self:AddToMotionController(phys)
				self.bone_translate[bone] = self:LookupBone(bone_name)

				local bone_parent = target:GetBoneParent(bone)
				bone_parent = target:TranslateBoneToPhysBone(bone_parent)
				bone_parent = target:TranslatePhysBoneToBone(bone_parent)
				local bone_name_parent = target:GetBoneName(bone_parent)

				self.bone_parent[bone] = bone_parent

				self.bone_translate[bone_parent] = self:LookupBone(bone_name_parent)
			end
		end
	end

	if !is_match then
		self:Remove()
		return
	end

	self.bone_head = self:LookupBone("ValveBiped.Bip01_Head1")

	if self.bone_head then
		self.phys_bone_head = self:TranslatePhysBoneToBone(self.bone_head)
	end

	self.Created = CurTime()

	target:DeleteOnRemove(self)

	self:SetMaxAngVel(400) --default

	if self.Module.Init then
		if self.InitParams then
			self.Module.Init(self, unpack(self.InitParams))
		else
			self.Module.Init(self)
		end
	end

	if self.Module.PhysicsCollide then
		self.PCCB = target:AddCallback("PhysicsCollide", function(ent, data)
			self.Module.PhysicsCollide(self, ent, data)
		end)
	end
end

function ENT:Think()
	if !self.Module then return end
	if self.Module.Think then
		self.Module.Think(self)
	end
end

function ENT:OnRemove()
	if !self.Module then return end
	if self.Module.OnRemove then
		self.Module.OnRemove(self)
	end
	local target = self:GetTarget()
	if (self.PCCB and IsValid(target)) then
		target:RemoveCallback("PhysicsCollide", self.PCCB)
	end
end

function ENT:UpdateTransmitState()
	return TRANSMIT_NEVER
	--return TRANSMIT_PVS
end

function ENT:PhysicsSimulate(phys, dt)
	local factor = 1

	if self.Module.PhysicsSimulate then
		local b, f = self.Module.PhysicsSimulate(self, phys, dt)
		if b == false then
			return
		end
		factor = f or factor
	end
	
	local target = self:GetTarget()

	local phys_bone = phys:GetID()

	if target.GS2IsDismembered then
		--decapitatied?
		if (self.phys_bone_head and target:GS2IsDismembered(self.phys_bone_head)) then
			self:Remove()
			return
		end
		local phys_bone = phys_bone
		local dis = false
		local bone = target:TranslatePhysBoneToBone(phys_bone)
		repeat
			phys_bone = target:TranslateBoneToPhysBone(bone)
			if target:GS2IsDismembered(phys_bone) then	
				dis = true
				break
			end
			bone = target:GetBoneParent(bone)
		until (phys_bone == 1 or phys_bone == 0)

		if (phys_bone == 0) then
			dis = target:GS2IsDismembered(1)
			if dis then
				self.StartDie = self.StartDie or CurTime()
			end
		elseif (phys_bone != 1) then
			dis = true
		end	

		if dis then
			self:RemoveFromMotionController(phys)
			return
		end
	end

	self:FrameAdvance()

	local bone = target:TranslatePhysBoneToBone(phys_bone)
	local bone_parent = self.bone_parent[bone]

	local self_bone = self.bone_translate[bone]
	local self_bone_parent = self.bone_translate[bone_parent]

	if (self_bone and self_bone_parent) then
		local _, bone_ang = self:GetBonePosition(self_bone)
		
		local _, bone_ang_parent = self:GetBonePosition(self_bone_parent)

		local _, lang = WorldToLocal(vector_origin, bone_ang, vector_origin, bone_ang_parent)

		local _, target_ang = LocalToWorld(vector_origin, lang, target:GetBonePosition(bone_parent))

		--TODO: clamp to ragdoll joint limits to avoid spazz

		local ang_vel = self:PhysAlignAngles(phys, target_ang)

		ang_vel:Mul(20 * factor)

		ang_vel:Sub(phys:GetAngleVelocity())

		if self.max_ang_vel then
			local len_sqr = ang_vel:LengthSqr()

			if (len_sqr > self.max_ang_vel_sqr) then
				ang_vel:Normalize()
				ang_vel:Mul(self.max_ang_vel)
			end
		end

		phys:AddAngleVelocity(ang_vel)

		--maybe this can work some day but that day is not today
		--[[local phys_bone_parent = target:TranslateBoneToPhysBone(self_bone_parent)
		local phys_parent = target:GetPhysicsObjectNum(phys_bone_parent)

		local _, lang = WorldToLocal(vector_origin, bone_ang_parent, vector_origin, bone_ang)

		local _, target_ang = LocalToWorld(vector_origin, lang, target:GetBonePosition(bone))

		--TODO: clamp to ragdoll joint limits to avoid spazz

		local ang_vel = self:PhysAlignAngles(phys_parent, target_ang)

		ang_vel:Mul(20 * factor)

		ang_vel:Sub(phys_parent:GetAngleVelocity())

		if self.max_ang_vel then
			local len_sqr = ang_vel:LengthSqr()

			if (len_sqr > self.max_ang_vel_sqr) then
				ang_vel:Normalize()
				ang_vel:Mul(self.max_ang_vel)
			end
		end

		phys_parent:AddAngleVelocity(ang_vel)]]
	end
endi