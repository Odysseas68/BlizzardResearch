local _, RetailUIResearch = ...;

RetailUIResearch.samples = {};
RetailUIResearch.sampleOrder = {};

function RetailUIResearch:RegisterSample(metadata)
	assert(metadata.id and metadata.name and metadata.frame, "Invalid RetailUIResearch sample metadata");
	assert(not self.samples[metadata.id], "Duplicate RetailUIResearch sample ID: " .. metadata.id);

	self.samples[metadata.id] = metadata;
	table.insert(self.sampleOrder, metadata);
end

function RetailUIResearch:GetSample(id)
	return self.samples[id];
end

function RetailUIResearch:GetSamples()
	return self.sampleOrder;
end

function RetailUIResearch:OpenSample(id)
	local sample = self.samples[id];
	if not sample then
		return false;
	end

	if self.activeSampleID and self.activeSampleID ~= id then
		local previousSample = self.samples[self.activeSampleID];
		if previousSample then
			previousSample.frame:Hide();
		end
	end

	self.activeSampleID = id;
	sample.frame:Show();
	return true;
end

function RetailUIResearch:ToggleSample(id)
	local sample = self.samples[id];
	if not sample then
		return false;
	end

	if sample.frame:IsShown() then
		sample.frame:Hide();
		if self.activeSampleID == id then
			self.activeSampleID = nil;
		end
		return true;
	end

	return self:OpenSample(id);
end
