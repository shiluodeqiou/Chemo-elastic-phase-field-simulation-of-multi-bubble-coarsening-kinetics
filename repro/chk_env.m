v = ver;
fprintf('--- TOOLBOXES ---\n');
for k=1:numel(v), fprintf('%s | %s\n', v(k).Name, v(k).Version); end
try
  g=gpuDevice; fprintf('GPU: %s CC=%s TotalMem=%.2f GB\n', g.Name, g.ComputeCapability, g.TotalMemory/1e9);
catch ME
  fprintf('GPU ERR: %s\n', ME.message);
end
fprintf('--- IMAGING: %d\n', exist('bwareaopen','file'));
fprintf('--- SIGNAL: %d\n', exist('smoothdata','file'));
