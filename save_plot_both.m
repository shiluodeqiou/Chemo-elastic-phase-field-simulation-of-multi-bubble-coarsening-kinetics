function save_plot_both(f,out_folder,base_name)
saveas(f,fullfile(out_folder,[base_name '.png']));
savefig(f,fullfile(out_folder,[base_name '.fig']));
close(f);
end