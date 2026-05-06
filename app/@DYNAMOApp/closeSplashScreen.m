function closeSplashScreen(~, fig)
%CLOSESPLASHSCREEN  Close the splash uifigure, enforcing the minimum
%visible lifetime stamped onto fig.UserData by showSplashScreen.

    if isempty(fig) || ~isvalid(fig); return; end

    try
        ud = fig.UserData;
        elapsed = toc(ud.startTic);
        remaining = ud.minLifetimeSec - elapsed;
        if remaining > 0
            pause(remaining);
        end
    catch
    end

    try
        delete(fig);
    catch
    end
end
