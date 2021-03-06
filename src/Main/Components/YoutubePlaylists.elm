module Main.Components.YoutubePlaylists exposing (..)

import Dict
import Html exposing (Html, button, div, text)
import Http
import List
import Main.Components.SyncVideosButton as SyncVideosButton
import Main.Errors as Errors
import Main.View.ErrorCard as ErrorCard
import Main.View.YoutubePlaylistsTable as YoutubePlaylistsTable
import Material
import Material.Button as Button
import Material.Options as Options
import Material.Typography as Typography
import Maybe.Extra
import PouchDB.Playlists as DBPlaylists
import Youtube.Playlist as YTPlaylists


type alias Model =
    { mdl : Material.Model
    , allYoutubePlaylists : Dict.Dict String YTPlaylists.YoutubePlaylist
    , selectedPlaylists : Dict.Dict String DBPlaylists.Doc
    , errors : List String
    }


type Msg
    = NoOp
    | Mdl (Material.Msg Msg)
    | FetchedPlaylistsListResp (Result Http.Error YTPlaylists.YoutubePlaylistsListResponse)
    | FetchAllPlaylists
    | DismissError
    | FetchedDBPlaylist DBPlaylists.Doc
    | FetchedDBPlaylists (List DBPlaylists.Doc)
    | DBPlaylistsErr String
    | SyncVideosButtonMsg SyncVideosButton.Msg


initialModel : Model
initialModel =
    { mdl = Material.model
    , allYoutubePlaylists = Dict.empty
    , selectedPlaylists = Dict.empty
    , errors = []
    }


selectedPlaylist : Model -> String -> Bool
selectedPlaylist model id =
    Dict.member id model.selectedPlaylists


view : Maybe String -> Model -> Html Msg
view token model =
    let
        selectedPlaylistIds =
            Dict.toList model.selectedPlaylists |> List.map (\( id, playlist ) -> playlist)
    in
    div []
        [ text "Playlists Component"
        , ErrorCard.view model.mdl model.errors DismissError Mdl
        , viewFetchPlaylistsButton token model
        , SyncVideosButton.view [ 64, 0 ] token selectedPlaylistIds model.mdl |> Html.map SyncVideosButtonMsg
        , viewPlaylists token model
        ]


viewFetchPlaylistsButton : Maybe String -> Model -> Html Msg
viewFetchPlaylistsButton token model =
    div []
        [ Button.render Mdl
            [ 0 ]
            model.mdl
            [ Button.raised
            , Button.ripple
            , Button.disabled |> Options.when (Maybe.Extra.isNothing token)
            , Options.onClick FetchAllPlaylists
            ]
            [ text "Fetch Playlists" ]
        ]


viewPlaylists : Maybe String -> Model -> Html Msg
viewPlaylists token model =
    let
        selectedPlaylists =
            Dict.toList model.selectedPlaylists |> List.map (\( _, x ) -> x)

        allPlaylists =
            Dict.toList model.allYoutubePlaylists
                |> List.map (\( x, pl ) -> pl)
                |> List.map DBPlaylists.fromYT
                |> List.sortBy .publishedAt
                |> List.reverse

        subModel playlists =
            { mdl = model.mdl
            , playlists = playlists
            , token = token
            }
    in
    div []
        [ Options.span [ Typography.title ] [ text "Saved Playlists" ]
        , YoutubePlaylistsTable.view (subModel selectedPlaylists) Mdl SyncVideosButtonMsg
        , Options.span [ Typography.title ] [ text "All Playlists" ]
        , YoutubePlaylistsTable.view (subModel allPlaylists) Mdl SyncVideosButtonMsg
        ]


update : Maybe String -> Msg -> Model -> ( Model, Cmd Msg )
update token msg model =
    case msg of
        NoOp ->
            model ! []

        Mdl msg_ ->
            Material.update Mdl msg_ model

        FetchedPlaylistsListResp playlistsRespResult ->
            case playlistsRespResult of
                Ok playlistsResp ->
                    let
                        newAllYtPlaylists =
                            List.foldr (\newPl allPls -> Dict.insert newPl.id newPl allPls) model.allYoutubePlaylists playlistsResp.items

                        nextCmd =
                            Maybe.map2 (\tkn nextPageTkn -> fetchPlaylists tkn (Just nextPageTkn)) token playlistsResp.nextPageToken
                    in
                    { model | allYoutubePlaylists = newAllYtPlaylists } ! [ Maybe.withDefault Cmd.none (Debug.log "next command " nextCmd) ]

                Err httpErr ->
                    { model | errors = [ Errors.extractBody httpErr ] |> List.append model.errors } ! []

        FetchAllPlaylists ->
            model ! [ Maybe.withDefault Cmd.none <| fetchAllPlaylists token ]

        DismissError ->
            { model | errors = [] } ! []

        FetchedDBPlaylist playlistDoc ->
            let
                newSelectedPlaylists =
                    Dict.insert playlistDoc.id playlistDoc model.selectedPlaylists
            in
            { model | selectedPlaylists = Debug.log "selected playlists " newSelectedPlaylists } ! []

        FetchedDBPlaylists playlists ->
            let
                selectedPlaylists =
                    List.map (\playlist -> ( playlist.id, playlist )) playlists |> Dict.fromList
            in
            { model | selectedPlaylists = selectedPlaylists } ! []

        DBPlaylistsErr err ->
            { model | errors = List.append model.errors [ err ] } ! []

        SyncVideosButtonMsg subMsg ->
            let
                ( mdlModel, subCmd, error ) =
                    SyncVideosButton.update token subMsg model.mdl

                newError =
                    Maybe.map (\x -> [ x ]) error |> Maybe.withDefault []
            in
            { model | errors = List.append model.errors newError, mdl = mdlModel } ! [ Cmd.map SyncVideosButtonMsg subCmd ]


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ DBPlaylists.fetchedPlaylist FetchedDBPlaylist
        , DBPlaylists.fetchedAllPlaylists FetchedDBPlaylists
        , DBPlaylists.playlistsErr DBPlaylistsErr
        , Sub.map SyncVideosButtonMsg SyncVideosButton.subscriptions
        ]


fetchAllPlaylists : Maybe String -> Maybe (Cmd Msg)
fetchAllPlaylists token =
    Maybe.map (\tkn -> fetchPlaylists tkn Nothing) token


fetchPlaylists : String -> Maybe String -> Cmd Msg
fetchPlaylists token nextPageToken =
    Http.send FetchedPlaylistsListResp <|
        YTPlaylists.getPlaylists token
            [ YTPlaylists.ContentDetails, YTPlaylists.SnippetPart ]
            (YTPlaylists.Mine True)
            (Just
                { hl = Nothing
                , maxResults = Just 50
                , onBehalfOfContentOwner = Nothing
                , onBehalfOfContentOwnerChannel = Nothing
                , pageToken = nextPageToken
                }
            )


cmdOnLoad : Maybe String -> Cmd Msg
cmdOnLoad token =
    Cmd.batch
        [ DBPlaylists.fetchAllPlaylists ()

        --, Maybe.withDefault Cmd.none <| fetchAllPlaylists token
        ]
