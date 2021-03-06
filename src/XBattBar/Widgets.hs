module XBattBar.Widgets (ProgressBar(colorBack, colorBar, progress), mkProgressBar,
                         Label(text), mkLabel) where

import Graphics.X11.Types (EventMask, cWOverrideRedirect)
import Graphics.X11.Xlib.Types hiding (Position)
import Graphics.X11.Xlib.Display (blackPixel, whitePixel)
import Graphics.X11.Xlib.Window (createSimpleWindow)
import Graphics.X11.Xlib.Event (flush, selectInput)
import Graphics.X11.Xlib.Misc (fillRectangles,
                               drawString,
                               allocaSetWindowAttributes,
                               set_override_redirect)
import Graphics.X11.Xlib.Context (setForeground, createGC)
import Graphics.X11.Xlib.Font (FontStruct,
                               ascentFromFontStruct,
                               descentFromFontStruct,
                               textWidth, loadQueryFont)
import Graphics.X11.Xlib.Extras (unmapWindow, changeWindowAttributes)

import XBattBar.Types

-- | progress bar-like widget
data ProgressBar = ProgressBar {
                 pbXContext     :: XContext,
                 pbExContext    :: ExtContext,
                 colorBack      :: Pixel,
                 colorBar       :: Pixel,
                 progress       :: Double,
                 orientation    :: Orientation
               }

instance XWidget ProgressBar
    where xContext = pbXContext
          widgetContext = pbExContext
          drawWidget bar = do
                let ctx'    = xContext bar
                    ectx'   = widgetContext bar
                    dpy'    = dpy ctx'
                    screen' = screen ctx'
                    window' = window ectx'
                    gc'     = gc ectx'
                    geom'   = geom ectx'
                    fg      = colorBar bar
                    bg      = colorBack bar
                setForeground dpy' gc' bg
                fillRectangles dpy' window' gc' [geom']
                setForeground dpy' gc' fg
                fillRectangles dpy' window' gc' [getIndicatorRect (orientation bar) (progress bar) geom']
                flush dpy'

getIndicatorRect :: Orientation -> Double -> Rectangle -> Rectangle
getIndicatorRect pos perc rect = case pos of
                        Horizontal ->
                            rect { rect_x = p (rect_width rect) - fromIntegral (rect_width rect), rect_y = 0 }
                        Vertical ->
                            rect { rect_y = fromIntegral (rect_height rect) - p (rect_height rect), rect_x = 0 }
                        where p x = floor $ perc * fromIntegral x

-- | creates a progress bar-like widget
mkProgressBar :: XContext -> Rectangle -> Pixel -> Pixel -> Orientation -> EventMask -> IO ProgressBar
mkProgressBar xctx geom fg bg orientation mask = do
    let dpy' = dpy xctx
        screen' = screen xctx
    f <- mkWidget xctx geom mask 0 ProgressBar
    return $ f fg bg 0.0 orientation

-- | multiline non-editable text widget with centered text
data Label = Label {
                 lXContext      :: XContext,
                 lExContext     :: ExtContext,
                 colorBG        :: Pixel,
                 colorFont      :: Pixel,
                 font           :: FontStruct,
                 text           :: [String]
             }

instance XWidget Label
    where xContext = lXContext
          widgetContext = lExContext
          drawWidget label = do
                let ctx'    = xContext label
                    ectx'   = widgetContext label
                    dpy'    = dpy ctx'
                    screen' = screen ctx'
                    window' = window ectx'
                    gc'     = gc ectx'
                    geom'   = geom ectx'
                    fg      = colorFont label
                    bg      = colorBG label
                    text'   = text label
                    font'   = font label
                    h       = ascentFromFontStruct font' + descentFromFontStruct font'
                    tw      = fromIntegral . textWidth font'
                    tx t    = fromIntegral $ rect_width geom' `div` 2 - (tw t) `div` 2
                    ty      = fromIntegral $ rect_height geom' `div` 2
                setForeground dpy' gc' bg
                fillRectangles dpy' window' gc' [geom']
                setForeground dpy' gc' fg
                mapM (\(s,y) -> drawString dpy' window' gc' (tx s) y s) $ zip text' [ty, (ty+h)..]
                flush dpy'
          handleWidgetEvent label ev et = drawWidget label

-- | creates a multiline non-editable text widget
mkLabel :: XContext -> Rectangle -> Pixel -> Pixel -> String -> [String] -> EventMask -> IO Label
mkLabel xctx geom fg bg fontName text mask = do
    let dpy' = dpy xctx
        screen' = screen xctx
    font <- loadQueryFont dpy' fontName
    f <- mkWidget xctx geom mask 2 Label
    return $ f bg fg font text

-- | wraps X11 window creation process
mkWidget :: XContext -> Rectangle -> EventMask -> Int -> (XContext -> ExtContext -> b) -> IO b
mkWidget ctx geom mask bw which = do
    let borderWidth = fromIntegral bw 
        dpy'    = dpy ctx
        screen' = screen ctx
        parent' = parent ctx
    window <- createSimpleWindow dpy' parent'
                                (rect_x geom)
                                (rect_y geom)
                                (rect_width geom)
                                (rect_height geom)
                                borderWidth
                                (blackPixel dpy' screen')
                                (whitePixel dpy' screen')
    allocaSetWindowAttributes $ \attrs -> do 
        set_override_redirect attrs True
        changeWindowAttributes dpy' window cWOverrideRedirect attrs
    gc <- createGC dpy' window
    selectInput dpy' window mask
    let ectx = ExtContext window geom gc
    return $ which ctx ectx
