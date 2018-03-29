module Main exposing (..)

import Html exposing (Html, button, div, h2, text)
import Html.Attributes exposing (class, classList)
import Html.Events exposing (onClick)
import Json.Decode
import Main.Route as Route
import Main.State exposing (..)
import Material
import Material.Color as Color
import Material.Dialog as Dialog
import Material.Icon as Icon
import Material.Layout as Layout
import Material.Options as Options exposing (cs, css, when)
import Material.Scheme
import Maybe
import Navigation
import PouchDB
import Main.Pages.Videos


main : Program Flags Model Msg
main =
    Navigation.programWithFlags NavigateTo
        { init = initWithFlags
        , update = update
        , subscriptions = subscriptions
        , view = view
        }


initWithFlags : Flags -> Navigation.Location -> ( Model, Cmd Msg )
initWithFlags flags location =
    ( { location = Route.locFor location
      , mdl = Material.model
      , videosPage = Main.Pages.Videos.initialModel

      , viewMode = ViewVideos
      , playlistItems = []
      , searchResults = []
      , searchTerms = Nothing
      , playlistResponses = []
      , err = Nothing
      , token = Nothing
      }
    , PouchDB.fetchVideos PouchDB.defaultFetchVideosArgs
    )


type alias Flags =
    { extensionId : String
    }



-- VIEW


view : Model -> Html Msg
view model =
    Material.Scheme.top <|
        Layout.render Mdl
            model.mdl
            [ Layout.fixedHeader
            , Options.css "display" "flex !important"
            , Options.css "flex-direction" "row"
            , Options.css "align-items" "center"
            ]
            { header = [ viewHeader model ]
            , drawer = [ viewDrawer model ]
            , tabs = ( [], [] )
            , main =
                [ viewBody model
                ]
            }



-- let
--     mainContent =
--         if model.viewMode == ViewVideos then
--             viewVideos2 model
--         else
--             viewSearchResults model
--     debug =
--         [ Html.p []
--             [ h2 [] [ text "Playlist Response" ]
--             , text (toString model.playlistResponses)
--             ]
--         , Html.p []
--             [ h2 [] [ text "Debug Error" ]
--             , text (toString model.err)
--             ]
--         ]
-- in
-- div [ class "columns" ]
--     [ div [ classList [ ( "column", True ), ( "is-2", True ) ] ] [ viewMenu model ]
--     , div [ class "column" ] ([ mainContent ] ++ debug)
--     ]


type alias MenuItem =
    { text : String
    , iconName : String
    , route : Maybe Route.Route
    }


menuItems : List MenuItem
menuItems =
    [ { text = "Home", iconName = "home", route = Just Route.Home }
    , { text = "Settings", iconName = "settings", route = Just Route.Settings }
    ]


viewDrawerMenuItem : Model -> MenuItem -> Html Msg
viewDrawerMenuItem model menuItem =
    let
        isCurrentLocation =
            model.location == menuItem.route

        onClickCmd =
            case ( isCurrentLocation, menuItem.route ) of
                ( False, Just route ) ->
                    route |> Route.urlFor |> NewUrl |> Options.onClick

                _ ->
                    Options.nop
    in
    Layout.link
        [ onClickCmd
        , when isCurrentLocation (Color.background <| Color.color Color.BlueGrey Color.S600)
        , Options.css "color" "rgba(255, 255, 255, 0.56)"
        , Options.css "font-weight" "500"
        ]
        [ Icon.view menuItem.iconName
            [ Color.text <| Color.color Color.BlueGrey Color.S500
            , Options.css "margin-right" "32px"
            ]
        , text menuItem.text
        ]


viewDrawer : Model -> Html Msg
viewDrawer model =
    Layout.navigation
        [ Color.background <| Color.color Color.BlueGrey Color.S800
        , Color.text <| Color.color Color.BlueGrey Color.S50
        , Options.css "flex-grow" "1"
        ]
    <|
        List.map (viewDrawerMenuItem model) menuItems
            ++ [ Layout.spacer
               , Layout.link
                    [ Dialog.openOn "click"
                    ]
                    [ Icon.view "help"
                        [ Color.text <| Color.color Color.BlueGrey Color.S500
                        ]
                    ]
               ]


viewHeader : Model -> Html Msg
viewHeader model =
    Layout.row
        []
        [ Layout.title [] [ text "PMedia Org" ] ]


viewBody : Model -> Html Msg
viewBody model =
    case model.location of
        Nothing ->
            text "404"

        Just Route.Home ->
            Main.Pages.Videos.view model.videosPage |> Html.map VideosMsg

        _ ->
            text "Not yet implemented"

-- OLD

viewPlaylistItem : PouchDB.Document -> Html Msg
viewPlaylistItem item =
    div []
        [ Html.ul []
            [ Html.li [] [ text <| "_id: " ++ item.id ]
            , Html.li [] [ text <| "title: " ++ item.video.title ]
            , Html.li [] [ Html.a [ Html.Attributes.target "_blank", Html.Attributes.href <| PouchDB.youtubeVideoUrl item ] [ text "link" ] ]
            , Html.li [] [ text <| "channelTitle: " ++ item.video.channelTitle ]
            , Html.li [] [ text <| "publishedAt: " ++ item.video.publishedAt ]
            , Html.li [] [ text <| "description: " ++ item.video.description ]
            , Html.li [] [ text <| "videoId: " ++ item.video.videoId ]
            , Html.li [] [ text <| "channelId: " ++ item.video.channelId ]
            , Html.li [] [ text <| "playlistId: " ++ item.video.playlistId ]
            , Html.li [] [ text <| "position: " ++ toString item.video.position ]
            ]
        ]


viewVideoItem : PouchDB.Document -> Html Msg
viewVideoItem item =
    let
        videoThumbnailUrl =
            Maybe.withDefault "" <|
                Maybe.map (\( name, thumb ) -> thumb.url) <|
                    List.head <|
                        List.filter (\( name, thumbnail ) -> name == "medium") item.video.thumbnails
    in
    div [ class "card" ]
        [ div [ class "card-image" ]
            [ Html.img [ Html.Attributes.src videoThumbnailUrl, Html.Attributes.alt item.video.title, Html.Attributes.width 320 ] []
            , div [ class "card-content" ]
                [ Html.p [ class "title is-6" ] [ text item.video.title ]
                , Html.p [ class "subtitle is-6" ] [ text item.video.publishedAt ]
                , div [ class "content" ] [ text item.video.description ]
                ]
            ]
        ]


viewVideos : Model -> Html Msg
viewVideos model =
    let
        nextAndPrevButtons =
            div []
                [ button
                    [ onClick <|
                        FetchVideos
                            { startKey = Maybe.map .id (List.head model.playlistItems)
                            , endKey = Nothing
                            , descending = True
                            , limit = PouchDB.defaultVideosLimitArg
                            }
                    ]
                    [ text "Prev" ]
                , button
                    [ onClick <|
                        FetchVideos
                            { startKey = Maybe.map .id (List.head <| List.reverse model.playlistItems)
                            , endKey = Nothing
                            , descending = False
                            , limit = PouchDB.defaultVideosLimitArg
                            }
                    ]
                    [ text "Next" ]
                ]

        playlistItemsHtml =
            List.map viewPlaylistItem model.playlistItems

        playlistItemsDivs =
            List.map insertPlaylistItemColumn playlistItemsHtml

        insertPlaylistItemColumn item =
            div [ class "column is-2 is-narrow" ] [ item ]
    in
    div []
        [ nextAndPrevButtons
        , div [ class "columns" ] playlistItemsDivs
        ]


viewVideos2 : Model -> Html Msg
viewVideos2 model =
    let
        nextAndPrevButtons =
            div []
                [ button
                    [ onClick <|
                        FetchVideos
                            { startKey = Maybe.map .id (List.head model.playlistItems)
                            , endKey = Nothing
                            , descending = True
                            , limit = PouchDB.defaultVideosLimitArg
                            }
                    ]
                    [ text "Prev" ]
                , button
                    [ onClick <|
                        FetchVideos
                            { startKey = Maybe.map .id (List.head <| List.reverse model.playlistItems)
                            , endKey = Nothing
                            , descending = False
                            , limit = PouchDB.defaultVideosLimitArg
                            }
                    ]
                    [ text "Next" ]
                ]

        playlistItemsHtml =
            List.map viewVideoItem model.playlistItems
    in
    div [] ([ nextAndPrevButtons ] ++ playlistItemsHtml)


viewMenu : Model -> Html Msg
viewMenu model =
    let
        authorizeYoutubeMenuItem =
            Html.li [] [ Html.a [ onClick <| AuthorizeYoutube True ] [ text "Authorize Youtube Login" ] ]

        generalMenuItems =
            [ searchInputMenuItem, authorizeYoutubeMenuItem ]
                ++ (Maybe.withDefault [] <| Maybe.map (\x -> [ x ]) <| syncYoutubeMenuItem model.token)
                ++ [ deleteDatabase ]

        deleteDatabase =
            Html.li [] [ Html.a [ onClick DeleteDatabase ] [ text "Debug Delete Database" ] ]
    in
    Html.aside [ class "menu" ]
        [ Html.p [ class "menu-label" ] [ text "General" ]
        , Html.ul [ class "menu-list" ] generalMenuItems
        ]


syncYoutubeMenuItem : Maybe String -> Maybe (Html Msg)
syncYoutubeMenuItem token =
    Maybe.map (\_ -> Html.li [] [ Html.a [ onClick FetchNewPlaylistItems ] [ text "Sync Youtube Playlists" ] ]) token


searchInputMenuItem : Html Msg
searchInputMenuItem =
    div [ class "field" ]
        [ div [ class "field-body" ]
            [ div [ class "field" ]
                [ div [ class "control" ] [ searchInputField ]
                ]
            ]
        ]


searchInputField : Html Msg
searchInputField =
    let
        -- send search on enter pressed
        handleKeyCode keyCode =
            if keyCode == 13 then
                StartSearch
            else
                NoOp

        onKeyPress =
            Html.Events.on "keypress" (Json.Decode.map handleKeyCode Html.Events.keyCode)

        onInput =
            Html.Events.onInput UpdateSearch
    in
    Html.input [ Html.Attributes.type_ "search", onKeyPress, onInput, class "input", Html.Attributes.placeholder "Search Youtube" ] []


viewSearchResults : Model -> Html Msg
viewSearchResults model =
    div [] <| List.map viewPlaylistItem model.searchResults
